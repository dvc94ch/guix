;;; Copyright © 2016 Efraim Flashner <efraim@flashner.co.il>
;;; Copyright © 2016 ng0 <ngillmann@runbox.com>
;;; Copyright © 2016 David Craven <david@craven.ch>
;;;
;;; This file is an addendum to GNU Guix.
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

(define-module (gnu packages inox)
  #:use-module (gnu packages)
  #:use-module (gnu packages assembly)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages certs)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cups)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages flex)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu packages gnuzilla)
  #:use-module (gnu packages gperf)
  #:use-module (gnu packages gstreamer)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages image)
  #:use-module (gnu packages libevent)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages ninja)
  #:use-module (gnu packages pciutils)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages photo)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages protobuf)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages python)
  #:use-module (gnu packages ruby)
  #:use-module (gnu packages serialization)
  #:use-module (gnu packages video)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xiph)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages xorg)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system perl)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (ice-9 format)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26))

;;;
;;; Inox configuration flags
;;;

;; https://github.com/gcarq/inox-patchset
(define %inox-flags
  (list "-Denable_google_now=0"
        "-Denable_webrtc=0"
        "-Denable_remoting=0"
        ;;"-Dsafe_browsing=0" ; Is currently broken and needs more work
        "-Denable_rlz=0"
        "-Denable_hangout_services_extension=0"
        "-Denable_wifi_bootstrapping=0"
        "-Denable_speech_input=0"
        "-Denable_pre_sync_backup=0"
        "-Denable_print_preview=0"
        "-Dgoogle_chrome_build=0"))

;; https://github.com/01org/ozone-wayland
(define %wayland-flags
  (list "-Dcomponent=static_library"
        "-Duse_ozone=1"
        "-Dozone_auto_platforms=1"
        "-Dozone_platform_wayland=1"
        "-Duse_xkbcommon=1"))

(define %use-system-flags
  ;; build/linux/unbundle/replace_gyp_files.py
  (list "-Duse_system_expat=1"
        "-Duse_system_ffmpeg=1"
        "-Duse_system_flac=1"
        "-Duse_system_harfbuzz=1"
        "-Duse_system_icu=0" ; FIXME
        "-Duse_system_jsoncpp=1"
        "-Duse_system_libevent=1"
        "-Duse_system_libjpeg=1"
        "-Duse_system_libpng=1"
        "-Duse_system_libusb=0" ; http://crbug.com/266149
        "-Duse_system_libvpx=1"
        "-Duse_system_libwebp=1"
        "-Duse_system_libxml=1"
        "-Duse_system_libxnvctrl=0" ; FIXME
        "-Duse_system_libxslt=1"
        "-Duse_system_opus=1"
        "-Duse_system_protobuf=1"
        "-Duse_system_re2=0" ; FIXME
        "-Duse_system_snappy=1"
        "-Duse_system_sqlite=0" ; http://crbug.com/22208
        "-Duse_system_v8=0"
        "-Duse_system_zlib=0" ; FIXME needs minizip
        ;; Other use system flags
        "-Duse_system_fontconfig=1" ; see build/common.gypi
        "-Duse_system_minigbm=0" ; see third-party/minigbm.gyp FIXME
        "-Duse_system_xdg_utils=1" ; see chrome/chrome_exe.gypi
        "-Duse_system_yasm=1" ; see build/common.gypi
        ))

(define %base-flags
  (list "-Dwerror="
        "-Dclang=0"
        "-Duse_sysroot=0"
        "-Dselinux=0"
        "-Dproprietary_codecs=0"
        "-Denable_widevine=0" ; DRM related
        "-Dlinux_use_bundled_binutils=0"
        "-Dlinux_use_bundled_gold=0"
        "-Dlinux_use_gold_flags=0"
        "-Ddisable_sse2=1" ; see build/common.gypi
        "-Dfastbuild=2"
        "-Denable_hidpi=1"
        ;; Disable gnome stuff
        "-Duse_gconf=0"
        "-Duse_gnome_keyring=0"
        ;; Disable nacl stuff
        "-Duse_mojo=0"
        "-Ddisable_nacl=1"
        "-Ddisable_pnacl=1"))

(define %chromium_conf
  (append %base-flags %inox-flags %use-system-flags))

;;;
;;; Inox patches
;;;

(define (patch-url name)
  "Return the URL of inox patch NAME."
  (string-append "https://raw.githubusercontent.com/gcarq/inox-patchset"
                 "/53.0.2785.101/" name))

(define (inox-patch patch)
  "Return the origin of inox patch NAME, with expected hash SHA256"
  (match patch
    (('quote (name hash))
     (origin
       (method url-fetch)
       (uri (patch-url name))
       (sha256 (base32 hash))))))

(define (inox-data patch)
  (match patch
    (('quote (name hash))
     (list name (inox-patch patch)))))

(define %inox-launcher-patches
  '('("launcher-branding.patch"
      "0zkjj9zjkxgpb7djaxlyxlasq1ghy19grrfmfm9i7h8l50drf4l4")))

(define %inox-patches-53.0.2785.101
  '('("add-duckduckgo-search-engine.patch"
      "0ldmmkhybwcckcamxb0nkl0xrkrnz8csr4x53ic27p6mg90yd2jh")
    '("branding.patch"
      "001xrzw9ghx9i3rma3r638zxrdwnv7k34nfgvyqwmc5f4andsvpy")
    '("chromium-52.0.2743.116-unset-madv_free.patch"
      "09y2c46w65ndzv3fj0ishql33cb3jkkk4y0wxlwzbri9iziajfiv")
    '("chromium-sandbox-pie.patch"
      "0j75nhmvynw1rl2x0w4ab951nfcsbfwf3y19b71gffcxbxk2n3fd")
    ;;'("chromium-widevine.patch"
    ;;  "024q1kqd3y931z75906r8hf849a2xb4cqfcxflavwzss5s9cpzfn")
    '("disable-autofill-download-manager.patch"
      "03fqxpdviqjddgfikp11hwf8nma1czy8q3zknjrxbwc5h06n0jrd")
    '("disable-battery-status-service.patch"
      "0yn87cjxzysfcw7wpdgd1ypv6c4am75pv5k193gyz6j6ks7r2vn4")
    '("disable-default-extensions.patch"
      "0qqs0x9whsixhq3ylaib3vz4xvhzrsrhcg8na6ayaxsril6zhmkd")
    '("disable-first-run-behaviour.patch"
      "04sgs990gihwdh60b3wdk9ryi3n505xk8nbfnvi4ybahiw1zwzn4")
    '("disable-gcm-status-check.patch"
      "07hll8yvnpmss0yldkrn5b9d6ack4qf7c463yambgyjzchpld0dh")
    '("disable-google-ipv6-probes.patch"
      "0z1w43sigpdl1fpnsh8rwh63slkv76n3p6gkm4vnbxs2hn2flbjn")
    '("disable-google-url-tracker.patch"
      "13j7j00ys7x5hdj6ra1rj43wz8dwmfvxxbdpwkgvixlr61zrscm7")
    '("disable-missing-key-warning.patch"
      "11g3yq53nj1qkqba9zy0h7vr6ja7sj3gjdq8r0lqjamdbapmvdsm")
    '("disable-new-avatar-menu.patch"
      "0g7zxvwlahpwgpg68rk843j5ls1r72y1jhd13dl60asar8fpadwy")
    '("disable-translation-lang-fetch.patch"
      "1kkx1pspy41bpcbvskdsa45a9jcg0s9rq4244azrph5ba4vmjqh3")
    '("disable-update-pings.patch"
      "1n6szvmijlssfymh7h4zymzjq0kkjpiisqbg7bqra5fmgp2f074y")
    '("disable-web-resource-service.patch"
      "1bhnwm9mi42ypxxsh8iw7cnqcgvwh0afhs6qg4dk8z93ilnvkfn2")
    '("modify-default-prefs.patch"
      "04gabn1lw6gclw9ppmmzxcqyzlqr27vr1afrrqyljjn89801wcrs")
    '("restore-classic-ntp.patch"
      "01xwggbmhiralbx90qvazdd8ynp6cmlaf00rznkwwk4qibx72i7d")))

(define %inox-data-53.0.2785.101
  '('("inox.desktop" "0j5ia11md0806ww65hbk48m0xs0yy30c4ddsqp0q5x2phyd96gzz")
    '("inox.install" "1pyzffw0if23yd74yn69w4znmqnswvx764zd4vfaxvgnkqjwhc76")
    '("product_logo_128.png" "1b9d4bdn1mxg3507ddnh1v4c45kk264g4m5lgnng1yafgnc96sc9")
    '("product_logo_16.png" "1pb877x90kjck9gs6517mj90sqmg4akfk8h4kq7l5508d6j1yivi")
    '("product_logo_22.png" "02g5cr9q3587hm4fgaxyq5cqr6qpx41hj72asyq6f5dwzg73llsa")
    '("product_logo_24.png" "1zbmi7rv1qfy8xz609byj0d589ylhplals5d2ksik60fbq68723v")
    '("product_logo_256.png" "0m3k6d4hbvqfax3n9vzhaia0wvmbqvf582a0kqyydz87vjxv7y9x")
    '("product_logo_32.png" "154xp8chgg2jv7b7i829mz9rc2if8wi68n6x3935nm8k7fqf644c")
    '("product_logo_48.png" "1sxyyahkncxryag1dwsna8vyxm6iqydl29rw2z1k8x1vv1qvf26c")
    '("product_logo_64.png" "1zznvm910q7380qrr0x4841043raq8iwky9smgbb97h633dfi8ak")))

;;;
;;; Inox launcher
;;;

(define inox-launcher
  (origin
    (method url-fetch)
    (uri "https://github.com/foutrelis/chromium-launcher/archive/v3.tar.gz")
    (file-name "chromium-launcher-3.tar.gz")
    (sha256
     (base32
      "0a2cp292zldprf21ysmkl34khnlynj84sxcahmwn452qzr7gn0cb"))
    (patches (map inox-patch %inox-launcher-patches))))

;;;
;;; Inox package
;;;

(define-public inox
  (package
    (name "inox")
    (version "53.0.2785.101")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://commondatastorage.googleapis.com"
                    "/chromium-browser-official/"
                    "chromium-" version ".tar.xz"))
              (sha256
               (base32
                "1q5fqhsnfv1485f16dbxc1f0biynv37qkvimpr8l41hi9gbmxigd"))
              ;; https://bugzilla.redhat.com/show_bug.cgi?id=1361157
              (patches (append (search-patches "inox-glibc-2.24.patch")
                               (map inox-patch %inox-patches-53.0.2785.101)))))
    (build-system gnu-build-system)
    (native-inputs
     `(("bison" ,bison)
       ("flex" ,flex)
       ("gperf" ,gperf)
       ("gzip" ,gzip)
       ,@(map inox-data %inox-data-53.0.2785.101)
       ("inox-launcher" ,inox-launcher)
       ("libvpx" ,libvpx)
       ("mesa" ,mesa)
       ("ninja" ,ninja)
       ("pkg-config" ,pkg-config)
       ("python-2" ,python-2)
       ("which" ,which)
       ("yasm" ,yasm)))
    (inputs
     `(("alsa-lib" ,alsa-lib)
       ("bzip2" ,bzip2)
       ("cairo" ,cairo)
       ("cups" ,cups)
       ("dbus" ,dbus)
       ("elfutils" ,elfutils)
       ("eudev" ,eudev)
       ("expat" ,expat)
       ("ffmpeg" ,ffmpeg)
       ("flac" ,flac)
       ("fontconfig" ,fontconfig)
       ("freetype" ,freetype)
       ("gdk-pixbuf" ,gdk-pixbuf)
       ("glib" ,glib)
       ("gtk-2" ,gtk+-2)
       ("harfbuzz" ,harfbuzz)
       ("jsoncpp" ,jsoncpp)
       ("libevent" ,libevent)
       ("libexif" ,libexif)
       ("libffi" ,libffi)
       ("libgcrypt" ,libgcrypt)
       ("libjpeg" ,libjpeg)
       ("libpng" ,libpng)
       ("libvpx" ,libvpx)
       ("libwebp" ,libwebp)
       ("libxcomposite" ,libxcomposite)
       ("libxcursor" ,libxcursor)
       ("libxdamage" ,libxdamage)
       ("libxext" ,libxext)
       ("libxfixes" ,libxfixes)
       ("libxi" ,libxi)
       ("libxinerama" ,libxinerama)
       ("libxkbcommon" ,libxkbcommon)
       ("libxml2" ,libxml2)
       ("libxrandr" ,libxrandr)
       ("libxrender" ,libxrender)
       ("libxscrnsaver" ,libxscrnsaver)
       ("libxslt" ,libxslt)
       ("libxtst" ,libxtst)
       ("nspr" ,nspr)
       ;; https://chromium.googlesource.com/chromium/deps/nss/+/master
       ;; http://crbug.com/58087
       ("nss" ,nss)
       ("opus" ,opus)
       ("pango" ,pango)
       ("pciutils" ,pciutils)
       ("perl" ,perl)
       ("perl-file-basedir" ,perl-file-basedir)
       ("perl-json" ,perl-json)
       ("protobuf" ,protobuf)
       ("pulseaudio" ,pulseaudio)
       ("python2-beautifulsoup4" ,python2-beautifulsoup4)
       ("python2-html5lib" ,python2-html5lib)
       ("python2-jinja2" ,python2-jinja2)
       ("python2-ply" ,python2-ply)
       ("python2-protobuf" ,python2-protobuf)
       ("python2-simplejson" ,python2-simplejson)
       ("ruby" ,ruby)
       ("snappy" ,snappy)
       ("xdg-utils" ,xdg-utils)
       ("zlib" ,zlib)))
    ;; Metabug: https://bugs.chromium.org/p/chromium/issues/detail?id=28287
    (arguments
     `(#:tests? #f ; Nope.
       #:parallel-build? #f ; Avoid python race condition.
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'patch-sources
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((eudev (assoc-ref inputs "eudev"))
                   (pciutils (assoc-ref inputs "pciutils")))
               (substitute* "build/common.gypi"
                 (("/bin/echo") "echo"))
               (substitute* "sandbox/linux/suid/client/setuid_sandbox_host.cc"
                 (("return sandbox_binary;")
                  "return base::FilePath(GetDevelSandboxPath());"))
               (substitute* (find-files "device/udev_linux" "udev._loader.cc")
                 (("libudev\\.so") (string-append eudev "/lib/libudev.so")))
               (substitute* "gpu/config/gpu_info_collector_linux.cc"
                 (("libpci\\.so") (string-append pciutils "/lib/libpci.so")))
               ;; Reverting a hack by the chromium developers that prevents
               ;; python2-protobuf from being used.
               (substitute* "chrome/browser/resources/safe_browsing/gen_file_type_proto.py"
                 (("if opts.wrap:") "if False:"))
               #t)))
         (add-after 'unpack 'setup-environment
           (lambda _
             ;; Prevent race conditions while writing pyc files.
             (setenv "PYTHONDONTWRITEBYTECODE" "1")
             #t))
         ;;(add-before 'configure 'precompile-python-files
         ;;  (lambda _
             ;; Precompile python files to prevent race conditions.
             ;; Ignore errors, there are some python 3 files.
         ;;    (system* "python" "-m" "compileall" "-q" "-f" ".")
         ;;    #t))
         (add-before 'configure 'unbundle
           (lambda _
             (zero? (system* "build/linux/unbundle/replace_gyp_files.py"
                             ,@%chromium_conf))))
         (replace 'configure
           (lambda _
             (zero? (system* "build/gyp_chromium" "--depth=."
                             ,@%chromium_conf))))
         (add-after 'configure 'patch-build.ninja
           (lambda _
             ;; Compiler isn't detected properly.
             (substitute* "out/Release/build.ninja"
               (("cc = cc") "cc = gcc"))
             (substitute* "out/Release/build.ninja"
               (("c++ = c++") "c++ = g++"))
             #t))
         (replace 'build
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((ninja (string-append (assoc-ref inputs "ninja") "/bin/ninja"))
                   (out   (assoc-ref outputs "out")))
               (zero? (system* ninja "-C" "out/Release"
                               "chrome" "chrome_sandbox" "chromedriver")))))
         (replace 'install
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out"))
                   (prefix (string-append "PREFIX=" out)))
               ;; add more later FIXME
               (zero? (system* "make" prefix install-strip))))))))
    (home-page "https://www.chromium.org/")
    (synopsis "Chromium web browser")
    (description "Chromium is an open-source browser project that aims
to build a safer, faster, and more stable way for all Internet users to
experience the web.")
    (license (list license:bsd-3 ; chromium
                   license:gpl3)))) ; patchset

(define-public perl-file-basedir
  (package
    (name "perl-file-basedir")
    (version "0.07")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://cpan/authors/id/K/KI/KIMRYAN/"
                    "File-BaseDir-" version ".tar.gz"))
              (sha256
               (base32
                "0aq8d4hsaxqibp36f773y6dfck7zd82v85sp8vhi6pjkg3pmf2hj"))))
    (build-system perl-build-system)
    (native-inputs
     `(("perl-file-which" ,perl-file-which)
       ("perl-module-build" ,perl-module-build)))
    (inputs
     `(("perl-ipc-system-simple" ,perl-ipc-system-simple)))
    (home-page "http://search.cpan.org/dist/File-BaseDir")
    (synopsis "Use the Freedesktop.org base directory specification")
    (description "fill-in-yourself!")
    (license (package-license perl))))

;;; inox.scm ends here
