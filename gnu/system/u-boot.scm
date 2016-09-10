;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2013, 2014, 2015, 2016 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2016 Danny Milosavljevic <dannym+a@scratchpost.org>
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

(define-module (gnu system u-boot)
  #:use-module (guix store)
  #:use-module (guix packages)
  #:use-module (guix derivations)
  #:use-module (guix records)
  #:use-module (guix monads)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (gnu artwork)
  #:use-module (gnu system file-systems)
  #:autoload   (gnu packages u-boot) (make-u-boot-package)
  #:use-module (gnu system grub) ; <menu-entry>
  #:use-module (ice-9 match)
  #:use-module (ice-9 regex)
  #:use-module (srfi srfi-1)
  #:export (u-boot-configuration
            u-boot-configuration?
            u-boot-configuration-package
            u-boot-configuration-device
            u-boot-configuration-file))

;;; Commentary:
;;;
;;; Configuration of U-Boot.
;;;
;;; Code:

(define-record-type* <u-boot-configuration>
  u-boot-configuration make-u-boot-configuration
  u-boot-configuration?
  (board           u-boot-board (default #f)) ; string
  (u-boot          u-boot-configuration-u-boot           ; package
                   (default #f)) ; will actually default to (make-u-boot-package board)
  (device          u-boot-configuration-device (default #f))        ; string
  (menu-entries    u-boot-configuration-menu-entries   ; list
                   (default '()))
  (default-entry   u-boot-configuration-default-entry  ; integer
                   (default 0))
  (timeout         u-boot-configuration-timeout        ; integer
                   (default 5)))



(define (u-boot-configuration-package config os)
  (or (u-boot-configuration-u-boot config)
      (make-u-boot-package (u-boot-configuration-board os))))

(define (linux-image-name system)
  (match system
    (("armhf-linux") "zImage")
    (_ "bzImage")))

;;;
;;; Configuration file.
;;;

(define* (u-boot-configuration-file config store-fs entries
                                  #:key
                                  (system (%current-system))
                                  (old-entries '()))
  "Return the U-Boot configuration file corresponding to CONFIG, a
<u-boot-configuration> object, and where the store is available at STORE-FS, a
<file-system> object.  OLD-ENTRIES is taken to be a list of menu entries
corresponding to old generations of the system."

  (define all-entries
    (append entries (u-boot-configuration-menu-entries config)))

  (define entry->gexp
    (match-lambda
     (($ <menu-entry> label linux arguments initrd)
      ;; TODO MENU LABEL hotkeys (using caret)
      #~(format port "LABEL ~s
  MENU LABEL ~a
  KERNEL ~a/~a
  FDTDIR ~a/lib/dtbs
  INITRD ~a
  APPEND ~a
~%"
                #$label #$label
                (dirname #$linux) #$(linux-image-name system)
                (dirname #$linux)
                #$initrd
                (string-join (list #$@arguments))))))

  (define builder
      #~(call-with-output-file #$output
          (lambda (port)
            (let ((timeout #$(u-boot-configuration-timeout config)))
              (format port "
DEFAULT ~a
PROMPT ~a
TIMEOUT ~a~%"
                      #$(u-boot-configuration-default-entry config)
                      (if (< timeout 0) 1 0)
                      (* 10 timeout))
            #$@(map entry->gexp all-entries)

            #$@(if (pair? old-entries)
                   #~((format port "~%")
                      #$@(map entry->gexp old-entries)
                      (format port "~%"))
                   #~())))))

    (gexp->derivation "extlinux.conf" builder))

;;; u-boot.scm ends here
