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
  #:use-module (gnu packages display-manager)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gstreamer)
  #:use-module (gnu packages kde-frameworks)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages lxqt)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages polkit)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages xdisorg)
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

(define-public hawaii-workspace
  (package
    (name "hawaii-workspace")
    (version "0.8.1")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/hawaii-desktop/hawaii-workspace"
                    "/releases/download/v" version "/"
                    "hawaii-workspace-" version ".tar.xz"))
              (sha256
               (base32
                "17jysr2zcbcph9v13w0qh8z7gwh01v45673sa74ybld1g5gw72bi"))))
    (build-system cmake-build-system)
    (native-inputs
     `(("extra-cmake-modules" ,extra-cmake-modules)
       ("glib:bin" ,glib "bin")
       ("pkg-config" ,pkg-config)
       ("qttools" ,qttools)))
    (inputs
     `(("fluid" ,fluid)
       ("glib" ,glib)
       ("greenisland" ,greenisland)
       ("hawaii-wallpapers" ,hawaii-wallpapers)
       ("libhawaii" ,libhawaii)
       ("polkit-qt" ,polkit-qt)
       ("qtbase" ,qtbase)
       ("qtdeclarative" ,qtdeclarative)
       ("qtquickcontrols" ,qtquickcontrols)
       ("qtquickcontrols2" ,qtquickcontrols2)
       ("qt-gstreamer" ,qt-gstreamer)
       ("wayland" ,wayland)))
    (arguments
     `(#:configure-flags
       (list (string-append "-DGSETTINGS_SCHEMA_DIR="
                            (assoc-ref %outputs "out") "/share/glib-2.0/schemas")
             (string-append "-DQT_PLUGIN_INSTALL_DIR="
                            (assoc-ref %outputs "out") "/plugins"))
       #:modules ((guix build cmake-build-system)
                  (guix build qt-utils)
                  (guix build utils))
       #:imported-modules (,@%cmake-build-system-modules
                           (guix build qt-utils))
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'patch-schemas
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((hawaii-wallpapers (assoc-ref inputs "hawaii-wallpapers")))
               (substitute* (find-files "data/settings" "\\.xml\\.in$")
                 (("@KDE_INSTALL_FULL_DATADIR@")
                  (string-append hawaii-wallpapers "/share"))))
             #t))
         (add-after 'install 'glib-compile-schemas
           (lambda* (#:key outputs #:allow-other-keys)
             (zero? (system* "glib-compile-schemas"
                             (string-append (assoc-ref outputs "out")
                                            "/share/glib-2.0/schemas")))))
         (add-after 'install 'wrap-programs
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (wrap-qt-program out "hawaii-polkit-agent")
               (wrap-qt-program out "hawaii-powermanager")
               (wrap-qt-program out "hawaii-screencast")
               (wrap-qt-program out "hawaii-screenshot")
               #t))))))
    (home-page "https://github.com/hawaii-desktop/hawaii-workspace")
    (synopsis "Base applications for Hawaii")
    (description "Base applications for the Hawaii desktop environment.")
    ;; Dual licensed
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public hawaii-icon-theme
  (package
    (name "hawaii-icon-theme")
    (version "0.8.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/hawaii-desktop/hawaii-icon-theme"
                    "/releases/download/v" version "/"
                    "hawaii-icon-theme-" version ".tar.xz"))
              (sha256
               (base32
                "142xz2fl9y6hd08bsn7h4bnmf2yz47jxvs783vrwry5wylqfdddn"))))
    (build-system cmake-build-system)
    (native-inputs
     `(("extra-cmake-modules" ,extra-cmake-modules)))
    (inputs
     `(("hicolor-icon-theme" ,hicolor-icon-theme)))
    (arguments
     `(#:tests? #f)) ; No tests
    (home-page "https://github.com/hawaii-desktop/hawaii-icon-theme")
    (synopsis "Icon and cursor theme")
    (description "Icon and cursor themes for the Hawaii desktop environment.")
    ;; Dual licensed
    (license (list license:gpl3+ license:lgpl3+))))

(define-public hawaii-wallpapers
  (package
    (name "hawaii-wallpapers")
    (version "0.8.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/hawaii-desktop/hawaii-wallpapers"
                    "/releases/download/v" version "/"
                    "hawaii-wallpapers-" version ".tar.xz"))
              (sha256
               (base32
                "1pbgjrc3v0lsm6d5ap3kikgp989lficsxazhfpv9kwar5ix12i26"))))
    (build-system cmake-build-system)
    (native-inputs
     `(("extra-cmake-modules" ,extra-cmake-modules)))
    (inputs
     `(("qtbase" ,qtbase)))
    (arguments
     `(#:tests? #f)) ; No tests
    (home-page "https://github.com/hawaii-desktop/hawaii-wallpapers")
    (synopsis "Wallpapers for Hawaii desktop environment")
    (description "Wallpapers for Hawaii desktop environment.")
    (license license:lgpl3+)))

(define-public hawaii-shell
  (package
    (name "hawaii-shell")
    (version "0.8.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/hawaii-desktop/hawaii-shell"
                    "/releases/download/v" version "/"
                    "hawaii-shell-" version ".tar.xz"))
              (sha256
               (base32
                "1x1i4kwpgizxmr15wrcrdph3wyvmdiygkpa0zhmxl7q65gg3986g"))))
    (build-system cmake-build-system)
    (native-inputs
     `(("extra-cmake-modules" ,extra-cmake-modules)
       ("pkg-config" ,pkg-config)))
    (inputs
     `(("alsa-lib" ,alsa-lib)
       ("fluid" ,fluid)
       ("glib" ,glib)
       ("greenisland" ,greenisland)
       ("hawaii-icon-theme" ,hawaii-icon-theme)
       ("hawaii-wallpapers" ,hawaii-wallpapers)
       ("hawaii-workspace" ,hawaii-workspace)
       ("hawaii-terminal" ,hawaii-terminal) ;remove
       ("dump-environment" ,dump-environment) ;remove
       ("libhawaii" ,libhawaii)
       ("libqtxdg" ,libqtxdg)
       ("mobile-broadband-provider-info" ,mobile-broadband-provider-info)
       ("modemmanager-qt" ,modemmanager-qt)
       ("networkmanager-qt" ,networkmanager-qt)
       ("libxkbcommon" ,libxkbcommon)
       ("linux-pam" ,linux-pam)
       ("pulseaudio" ,pulseaudio)
       ("qtbase" ,qtbase)
       ("qtdeclarative" ,qtdeclarative)
       ("qtgraphicaleffects" ,qtgraphicaleffects)
       ("qtquickcontrols" ,qtquickcontrols)
       ("qtquickcontrols2" ,qtquickcontrols2)
       ("qtsvg" ,qtsvg)
       ("qtwayland" ,qtwayland)
       ("solid" ,solid)
       ("wayland" ,wayland)))
    (arguments
     `(#:configure-flags
       (list "-DENABLE_SYSTEMD=OFF"
             (string-append "-DQML_INSTALL_DIR="
                            (assoc-ref %outputs "out") "/qml"))
       #:modules ((guix build cmake-build-system)
                  (guix build qt-utils)
                  (guix build utils))
       #:imported-modules (,@%cmake-build-system-modules
                           (guix build qt-utils))
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'patch-hawaii-session
           (lambda _
             (substitute* "scripts/hawaii-session.in"
               (("@CMAKE_INSTALL_FULL_BINDIR@/greenisland-launcher")
                (which "greenisland-launcher")))
             #t))
         ;;(add-after 'unpack 'patch-xdg-data-dirs
         ;;  (lambda _
         ;;    ;; Always set XDG_DATA_DIRS
         ;;    (substitute* "compositor/main.cpp"
         ;;      (("if \\(qEnvironmentVariableIsEmpty\\(\"XDG_DATA_DIRS\"\\)\\)") ""))
         ;;    ;; Always set XDG_CONFIG_DIRS
         ;;    (substitute* "compositor/main.cpp"
         ;;      (("if \\(qEnvironmentVariableIsEmpty\\(\"XDG_CONFIG_DIRS\"\\)\\)") ""))
         ;;    ;; Set XDG_DATA_DIRS to /run/current-system/profile/share
         ;;    (substitute* "compositor/main.cpp"
         ;;      (("/usr/local/share/:/usr/share/") "/run/current-system/profile/share"))
         ;;    ;; Set XDG_CONFIG_DIRS to /run/current-system/profile/etc/xdg
         ;;    (substitute* "compositor/main.cpp"
         ;;      (("/etc/xdg") "/run/current-system/profile/etc/xdg"))
         ;;    #t))
         (add-after 'install 'wrap-programs
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out"))
                   (workspace (assoc-ref inputs "hawaii-workspace")))
               (wrap-qt-program out "hawaii")
               (wrap-qt-program out "hawaii-session")
               (wrap-program (string-append out "/bin/hawaii-session")
                 `("GSETTINGS_SCHEMA_DIR" ":" prefix
                   (,(string-append workspace "/share/glib-2.0/schemas")))))
             #t)))))
    (home-page "https://github.com/hawaii-desktop/hawaii-shell")
    (synopsis "QtQuick and Wayland desktop shell")
    (description "This is the Hawaii desktop environment shell and workspace.
It contains a Qt platform theme plugin, session manager, QML plugins and a
convergent shell for multiple form factors such as desktops, netbooks, phones
and tablets.")
    ;; Dual licensed
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public hawaii-terminal
  (package
    (name "hawaii-terminal")
    (version "0.6.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/hawaii-desktop/hawaii-terminal"
                    "/releases/download/v" version "/"
                    "hawaii-terminal-" version ".tar.xz"))
              (sha256
               (base32
                "0cksjfacx4k2v0v66bb32fxa4jsa9icllzyizs83s4axm73xd3mx"))))
    (build-system cmake-build-system)
    (native-inputs
     `(("extra-cmake-modules" ,extra-cmake-modules)))
    (inputs
     `(("qtbase" ,qtbase)
       ("qtdeclarative" ,qtdeclarative)
       ("qtquickcontrols" ,qtquickcontrols)
       ("qtwayland" ,qtwayland)
       ("hawaii-workspace" ,hawaii-workspace)
       ("hawaii-widget-styles" ,hawaii-widget-styles)))
    (arguments
     `(#:configure-flags
       (list (string-append "-DQML_INSTALL_DIR="
                            (assoc-ref %outputs "out") "/qml"))
       #:modules ((guix build cmake-build-system)
                  (guix build qt-utils)
                  (guix build utils))
       #:imported-modules (,@%cmake-build-system-modules
                           (guix build qt-utils))
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'patch-desktop-file
           (lambda* (#:key outputs #:allow-other-keys)
             (substitute* "data/org.hawaiios.terminal.desktop"
               (("hawaii-terminal")
                (string-append (assoc-ref outputs "out")
                               "/bin/hawaii-terminal")))
             #t))
         (add-after 'install 'wrap-program
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (wrap-qt-program out "hawaii-terminal"))
             #t)))))
    (home-page "https://github.com/hawaii-desktop/hawaii-terminal")
    (synopsis "Terminal emulator")
    (description "Terminal emulator for the Hawaii desktop environment.")
    (license license:gpl2+)))

(define-public hawaii-system-preferences
  (package
    (name "hawaii-system-preferences")
    (version "0.8.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/hawaii-desktop/hawaii-system-preferences"
                    "/releases/download/v" version "/"
                    "hawaii-system-preferences-" version ".tar.xz"))
              (sha256
               (base32
                "0dxsm1lapw04j5glizqhaf6g6d16i7fnyfxbsflwsa9xspmhszr1"))))
    (build-system cmake-build-system)
    (native-inputs
     `(("extra-cmake-modules" ,extra-cmake-modules)
       ("qttools" ,qttools)))
    (inputs
     `(("fluid" ,fluid)
       ("greenisland" ,greenisland)
       ("libhawaii" ,libhawaii)
       ("polkit-qt" ,polkit-qt)
       ("qtbase" ,qtbase)
       ("qtdeclarative" ,qtdeclarative)
       ("qtquickcontrols" ,qtquickcontrols)
       ("qtquickcontrols2" ,qtquickcontrols2)
       ("wayland" ,wayland)))
    (arguments
     `(#:configure-flags
       (list (string-append "-DQML_INSTALL_DIR="
                            (assoc-ref %outputs "out") "/qml"))
       #:modules ((guix build cmake-build-system)
                  (guix build qt-utils)
                  (guix build utils))
       #:imported-modules (,@%cmake-build-system-modules
                           (guix build qt-utils))
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'patch-desktop-file
           (lambda* (#:key outputs #:allow-other-keys)
             (substitute* "data/org.hawaiios.SystemPreferences.desktop"
               (("hawaii-system-preferences")
                (string-append (assoc-ref outputs "out")
                               "/bin/hawaii-system-preferences")))
             #t))
         (add-after 'install 'wrap-program
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (wrap-qt-program out "hawaii-system-preferences"))
           #t)))))
    (home-page "https://github.com/hawaii-desktop/hawaii-system-preferences")
    (synopsis "System preferences application and modules")
    (description "System preferences for the Hawaii desktop environment.")
    ;; Dual licensed
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public eyesight
  (package
    (name "eyesight")
    (version "0.1.4")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/hawaii-desktop/eyesight"
                    "/releases/download/v" version "/"
                    "eyesight-" version ".tar.xz"))
              (sha256
               (base32
                "0531ivvs315mpkrmdpkgb99s6fsr294zv0gdzrbpp9nmkwpslkkp"))))
    (build-system cmake-build-system)
    (native-inputs
     `(("extra-cmake-modules" ,extra-cmake-modules)
       ("qttools" ,qttools)))
    (inputs
     `(("qtbase" ,qtbase)))
    (arguments
     `(#:tests? #f ; No tests
       #:modules ((guix build cmake-build-system)
                  (guix build qt-utils)
                  (guix build utils))
       #:imported-modules (,@%cmake-build-system-modules
                           (guix build qt-utils))
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'patch-desktop-file
           (lambda* (#:key outputs #:allow-other-keys)
             (substitute* "data/eyesight.desktop"
               (("eyesight")
                (string-append (assoc-ref outputs "out")
                               "/bin/eyesight")))
             #t))
         (add-after 'install 'wrap-program
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (wrap-qt-program out "eyesight"))
             #t)))))
    (home-page "https://github.com/hawaii-desktop/eyesight")
    (synopsis "Image viewer")
    (description "Image viewer for the Hawaii desktop environment.")
    (license license:gpl2+)))

(define-public hawaii-widget-styles
  (package
    (name "hawaii-widget-styles")
    (version "0.8.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/hawaii-desktop/hawaii-widget-styles"
                    "/releases/download/v" version "/"
                    "hawaii-widget-styles-" version ".tar.xz"))
              (sha256
               (base32
                "0kch4d1ys51zh0840pjccvba903lrxh37q5vqz1sj0q2vxlaksm1"))))
    (build-system cmake-build-system)
    (native-inputs
     `(("extra-cmake-modules" ,extra-cmake-modules)))
    (inputs
     `(("qtbase" ,qtbase)
       ("qtdeclarative" ,qtdeclarative)
       ("qtquickcontrols" ,qtquickcontrols)))
    (arguments
     `(#:configure-flags
       (list (string-append "-DQML_INSTALL_DIR="
                            (assoc-ref %outputs "out") "/qml"))))
    (home-page "https://github.com/hawaii-desktop/hawaii-widget-styles")
    (synopsis "Styles for applications using qtquickcontrols")
    (description "Styles for applications using qtquickcontrols.")
    (license license:lgpl2.1+)))

(define-public hawaii-plymouth-theme
  (package
    (name "hawaii-plymouth-theme")
    (version "0.2.2")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/hawaii-desktop/hawaii-plymouth-theme"
                    "/archive/v" version ".tar.gz"))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256
               (base32
                "0wk0pr2s4csz4zbcf6rvw076pbmxwhnk45gw0pkb793spw4pw7ls"))))
    (build-system cmake-build-system)
    (arguments
     `(#:tests? #f)) ; No tests
    (home-page "https://github.com/hawaii-desktop/hawaii-plymouth-theme")
    (synopsis "Hawaii theme for plymouth")
    (description "Hawaii theme for plymouth.")
    (license #f)))

(use-modules (guix build-system trivial))

(define-public dump-environment
  (package
    (name "dump-environment")
    (version "1")
    (source #f)
    (build-system trivial-build-system)
    (outputs '("out"))
    (synopsis "Dump environment to file")
    (arguments
     `(#:modules ((guix build utils)
                  (ice-9 format))
       #:builder
       (begin
         (use-modules (guix build utils)
                      (ice-9 format))

         (let* ((out (assoc-ref %outputs "out"))
                (bin (string-append out "/bin"))
                (share (string-append out "/share"))
                (applications (string-append share "/applications"))
                (script (string-append bin "/dump-environment.sh"))
                (desktop (string-append applications "/dump-environment.desktop"))
                (exec "/run/current-system/profile/bin/env"))
           (mkdir-p bin)
           (mkdir-p applications)

           (with-output-to-file script
             (lambda _
               (format #t "#!/run/current-system/profile/bin/bash~%")
               (format #t "env > ~/.local/share/sddm/environment-dump.log~%")))

           (with-output-to-file desktop
             (lambda _
               (format #t "[Desktop Entry]~%")
               (format #t "Name=~a~%" ,name)
               (format #t "Version=1.0~%")
               (format #t "Comment=~a~%" ,synopsis)
               (format #t "Type=Application~%")
               (format #t "Icon=~a~%" "accessories-calculator")
               (format #t "TryExec=~a~%" exec)
               (format #t "Exec=~a~%" exec)
               (format #t "Categories=~a~%" "X-Hawaii;Development;")))

           (chmod script #o777)))))
    (home-page #f)
    (description #f)
    (license #f)))

;; TODO: Add hawaii-calamares-branding (currently no release available)
;;       Add qtaccountservice and qtconfiguration
;;       Use hawaii themes for qtquickcontrols and sddm
;; FIXME: Failed to get image from provider: image://desktoptheme/input-keyboard
;;        Finding applications
