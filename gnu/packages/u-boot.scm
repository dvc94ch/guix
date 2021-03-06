;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2016 Danny Milosavljevic <dannym@scratchpost.org>
;;; Copyright © 2016 David Craven <david@craven.ch>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gnu packages u-boot)
  #:use-module (guix build-system gnu)
  #:use-module (guix download)
  #:use-module (guix packages)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  #:use-module ((gnu packages algebra) #:select (bc))
  #:use-module (gnu packages bison)
  #:use-module (gnu packages cross-base)
  #:use-module (gnu packages flex)
  #:use-module (gnu packages python)
  #:use-module (gnu packages tls)
  #:use-module (ice-9 match))

(define-public dtc
  (package
    (name "dtc")
    (version "1.4.2")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://www.kernel.org/pub/software/utils/dtc/"
                    "dtc-" version ".tar.xz"))
              (sha256
               (base32
                "1b7si8niyca4wxbfah3qw4p4wli81mc1qwfhaswvrfqahklnwi8k"))))
    (build-system gnu-build-system)
    (native-inputs
     `(("bison" ,bison)
       ("flex" ,flex)))
    (arguments
     `(#:make-flags
       (list "CC=gcc"
             (string-append "PREFIX=" (assoc-ref %outputs "out"))
             "INSTALL=install")
       #:phases
       (modify-phases %standard-phases
         (delete 'configure))))
    (home-page "https://www.devicetree.org")
    (synopsis "Compiles device tree source files")
    (description "@command{dtc} compiles device tree source files to device
tree binary files. These are board description files used by Linux and BSD.")
    (license license:gpl2+)))

(define u-boot
  (package
    (name "u-boot")
    (version "2016.07")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "ftp://ftp.denx.de/pub/u-boot/"
                    "u-boot-" version ".tar.bz2"))
              (sha256
               (base32
                "0lqj4ckmfqiap8mc6z2d5albs3g2h5mzccbn60hsgxhabhibfkwp"))))
    (native-inputs
     `(("bc" ,bc)
       ("dtc" ,dtc)
       ("openssl" ,openssl)
       ("python-2" ,python-2)))
    (build-system  gnu-build-system)
    (home-page "http://www.denx.de/wiki/U-Boot/")
    (synopsis "ARM bootloader")
    (description "U-Boot is a bootloader used mostly for ARM boards. It
also initializes the boards (RAM etc).")
    (license license:gpl2+)))

(define (make-u-boot-package board triplet files-to-install)
  "Returns a u-boot package for BOARD cross-compiled for TRIPLET. If
triplet is false or (cross-target-triplet->system triplet) matches
the %current-system compile natively."
  (let* ((system (cross-target-triplet->system triplet))
         (triplet (if (string=? (or system "") (%current-system)) #f triplet)))
    (package
      (inherit u-boot)
      (name (string-append "u-boot-" (string-downcase board)))
      (native-inputs
       `(,@(package-native-inputs u-boot)
         ,@(if triplet
               `(("cross-gcc" ,(cross-gcc triplet))
                 ("cross-binutils" ,(cross-binutils triplet)))
               '())))
      (arguments
       `(#:test-target "test"
         #:make-flags
         (list "HOSTCC=gcc" ,@(if triplet
                                  `((string-append "CROSS_COMPILE=" ,triplet "-"))
                                  '()))
         #:phases
         (modify-phases %standard-phases
           (replace 'configure
             (lambda* (#:key outputs make-flags #:allow-other-keys)
               (let ((config-name (string-append ,board "_defconfig")))
                 (if (file-exists? (string-append "configs/" config-name))
                     (zero? (apply system* "make" (cons config-name make-flags)))
                     (begin
                       (display "Invalid board name. Valid board names are:")
                       (let ((dir (opendir "configs"))
                             (suffix-length (string-length "_defconfig")))
                         (do ((file-name (readdir dir) (readdir dir)))
                             ((eof-object? file-name))
                           (when (string-suffix? "_defconfig" file-name)
                             (format #t "- ~A\n"
                                     (string-drop-right file-name suffix-length))))
                         (closedir dir))
                       #f)))))
           (replace 'install
             (lambda* (#:key outputs #:allow-other-keys)
               (for-each (lambda (file)
                           (let* ((out (assoc-ref outputs "out"))
                                  (target-file (string-append out "/" file)))
                             (mkdir-p (dirname target-file))
                             (copy-file file target-file)))
                         '(,@files-to-install))))))))))

;;;
;;; Arch support
;;;

(define (cross-target-triplet->system triplet)
  (match triplet
    (("arm-linux-gnueabihf") "armhf-linux")
    (("mips64el-linux-gnueabi64") "mips64el-linux")
    (_ #f)))

(define make-arm-u-boot-package
  (lambda (board files-to-install)
    (make-u-boot-package board "arm-linux-gnueabihf" files-to-install)))

(define make-mips-u-boot-package
  (lambda (board files-to-install)
    (make-u-boot-package board "mips64el-linux-gnuabi64" files-to-install)))

;;;
;;; Board support
;;;

(define-public u-boot-vexpress
  (make-arm-u-boot-package "vexpress_ca9x4" '("u-boot.bin")))

(define-public u-boot-malta
  (make-mips-u-boot-package "malta" '("u-boot.bin")))

(define-public u-boot-wandboard
  (make-arm-u-boot-package "wandboard" '("SPL" "u-boot.img")))

(define-public u-boot-beagle-bone-black
  (make-arm-u-boot-package "am335x_boneblack" '("MLO" "u-boot.img")))

(define-public u-boot-zybo
  ;; http://lists.denx.de/pipermail/u-boot/2015-February/203652.html
  ;; TODO: Generate boot.bin file.
  (make-arm-u-boot-package "zynq_zybo" '("u-boot-dtb.img")))
