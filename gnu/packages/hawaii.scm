;;; GNU Guix --- Functional package management for GNU
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

(define-module (gnu packages hawaii)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages kde-frameworks)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages qt)
  #:use-module (guix build-system cmake)
  #:use-module (guix download)
  #:use-module (guix packages)
  #:use-module ((guix licenses) #:prefix license:))

(define-public fluid
  (package
    (name "fluid")
    (version "0.8.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/hawaii-desktop/fluid"
                    "/releases/download/v" version "/"
                    "fluid-" version ".tar.xz"))
              (sha256
               (base32
                "0f1xirjlli6r0mgky0a58w6ph3raihcwbck4my59mf12365hh57m"))))
    (build-system cmake-build-system)
    (native-inputs
     `(("extra-cmake-modules" ,extra-cmake-modules)))
    (inputs
     `(("qtbase" ,qtbase)
       ("qtdeclarative" ,qtdeclarative)
       ("qtquickcontrols" ,qtquickcontrols)
       ("qtquickcontrols2" ,qtquickcontrols2)))
    (arguments
     `(#:configure-flags
       (list (string-append "-DQML_INSTALL_DIR="
                            (assoc-ref %outputs "out") "/qml"))))
    (home-page "https://github.com/hawaii-desktop/fluid")
    (synopsis "Library for QtQuick applications")
    (description "Modules for fluid and dynamic applications development with
QtQuick.")
    (license license:lgpl2.1+)))

(define-public libhawaii
  (package
    (name "libhawaii")
    (version "0.8.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/hawaii-desktop/libhawaii"
                    "/releases/download/v" version "/"
                    "libhawaii-" version ".tar.xz"))
              (sha256
               (base32
                "0hl2q0s80wi11pjjsmd1icjm9lz00yi0jjvmygsmvxym3zkmapbw"))))
    (build-system cmake-build-system)
    (native-inputs
     `(("extra-cmake-modules" ,extra-cmake-modules)
       ("pkg-config" ,pkg-config)))
    (inputs
     `(("glib" ,glib)
       ("qtbase" ,qtbase)
       ("qtdeclarative" ,qtdeclarative)))
    (arguments
     `(#:configure-flags
       (list (string-append "-DQML_INSTALL_DIR="
                            (assoc-ref %outputs "out") "/qml"))
       #:phases
       (modify-phases %standard-phases
         ;; install and check phase are swapped so that qml files
         ;; are located in QML_INSTALL_DIR
         (add-after 'install 'check-post-install
           (assoc-ref %standard-phases 'check))
         (delete 'check)
         (add-before 'check-post-install 'check-setup
           (lambda* (#:key outputs #:allow-other-keys)
             (setenv "QML2_IMPORT_PATH"
                     (string-append (getenv "QML2_IMPORT_PATH") ":"
                                    (assoc-ref outputs "out") "/qml"))
             (setenv "QT_QPA_PLATFORM" "offscreen")
             #t)))))
    (home-page "https://github.com/hawaii-desktop/libhawaii")
    (synopsis "Support library for the shell and applications")
    (description "These are the libraries used by Hawaii Shell and other
projects related to the Hawaii desktop environment.")
    ;; Dual licensed
    (license (list license:gpl2+ license:lgpl3+))))
