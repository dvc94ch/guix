;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2016 Ludovic Courtès <ludo@gnu.org>
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

(define-module (gnu tests ssh)
  #:use-module (gnu tests)
  #:use-module (gnu system)
  #:use-module (gnu system grub)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system shadow)
  #:use-module (gnu system vm)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services ssh)
  #:use-module (gnu services networking)
  #:use-module (gnu packages ssh)
  #:use-module (guix gexp)
  #:use-module (guix store)
  #:use-module (guix monads)
  #:export (%test-openssh
            %test-dropbear))

(define %base-os
  (operating-system
    (host-name "komputilo")
    (timezone "Europe/Berlin")
    (locale "en_US.UTF-8")

    (bootloader (grub-configuration (device "/dev/sdX")))
    (file-systems %base-file-systems)
    (firmware '())
    (users %base-user-accounts)
    (services (cons (dhcp-client-service)
                    %base-services))))

(define (os-with-service service)
  "Return a test operating system that runs SERVICE."
  (operating-system
    (inherit %base-os)
    (services (cons service
                    (operating-system-user-services %base-os)))))

(define (run-ssh-test name ssh-service pid-file)
  "Run a test of an OS running SSH-SERVICE, which writes its PID to PID-FILE.
SSH-SERVICE must be configured to listen on port 22 and to allow for root and
empty-password logins."
  (mlet* %store-monad ((os ->   (marionette-operating-system
                                 (os-with-service ssh-service)
                                 #:imported-modules '((gnu services herd)
                                                      (guix combinators))))
                       (command (system-qemu-image/shared-store-script
                                 os #:graphic? #f)))
    (define test
      (with-imported-modules '((gnu build marionette))
        #~(begin
            (eval-when (expand load eval)
              ;; Prepare to use Guile-SSH.
              (set! %load-path
                (cons (string-append #$guile-ssh "/share/guile/site/"
                                     (effective-version))
                      %load-path)))

            (use-modules (gnu build marionette)
                         (srfi srfi-26)
                         (srfi srfi-64)
                         (ice-9 match)
                         (ssh session)
                         (ssh auth)
                         (ssh channel))

            (define marionette
              ;; Enable TCP forwarding of the guest's port 22.
              (make-marionette (list #$command "-net"
                                     "user,hostfwd=tcp::2222-:22")))

            (define (wait-for-file file)
              ;; Wait until FILE exists in the guest; 'read' its content and
              ;; return it.
              (marionette-eval
               `(let loop ((i 10))
                  (cond ((file-exists? ,file)
                         (call-with-input-file ,file read))
                        ((> i 0)
                         (sleep 1)
                         (loop (- i 1)))
                        (else
                         (error "file didn't show up" ,file))))
               marionette))

            (mkdir #$output)
            (chdir #$output)

            (test-begin "ssh-daemon")

            ;; Wait for sshd to be up and running.
            (test-eq "service running"
              'running!
              (marionette-eval
               '(begin
                  (use-modules (gnu services herd))
                  (start-service 'ssh-daemon)
                  'running!)
               marionette))

            ;; Check sshd's PID file.
            (test-equal "sshd PID"
              (wait-for-file #$pid-file)
              (marionette-eval
               '(begin
                  (use-modules (gnu services herd)
                               (srfi srfi-1))

                  (live-service-running
                   (find (lambda (live)
                           (memq 'ssh-daemon
                                 (live-service-provision live)))
                         (current-services))))
               marionette))

            ;; Connect to the guest over SSH.  We should be able to connect as
            ;; "root" with an empty password.  Make sure we can run a shell
            ;; command there.
            (test-equal "connect"
              'hello
              (let* ((session (make-session #:user "root"
                                            #:port 2222 #:host "localhost"
                                            #:log-verbosity 'protocol)))
                (match (connect! session)
                  ('ok
                   ;; Try the simple authentication methods.  Dropbear
                   ;; requires 'none' when there are no passwords, whereas
                   ;; OpenSSH accepts 'password' with an empty password.
                   (let loop ((methods (list (cut userauth-password! <> "")
                                             (cut userauth-none! <>))))
                     (match methods
                       (()
                        (error "all the authentication methods failed"))
                       ((auth rest ...)
                        (match (pk 'auth (auth session))
                          ('success
                           ;; FIXME: 'get-server-public-key' segfaults.
                           ;; (get-server-public-key session)
                           (let ((channel (make-channel session)))
                             (channel-open-session channel)
                             (channel-request-exec channel
                                                   "echo hello > /root/witness")
                             (and (zero? (channel-get-exit-status channel))
                                  (wait-for-file "/root/witness"))))
                          ('denied
                           (loop rest))))))))))

            (test-end)
            (exit (= (test-runner-fail-count (test-runner-current)) 0)))))

    (gexp->derivation name test)))

(define %test-openssh
  (system-test
   (name "openssh")
   (description "Connect to a running OpenSSH daemon.")
   (value (run-ssh-test name
                        ;; Allow root logins with an empty password to
                        ;; simplify testing.
                        (service openssh-service-type
                                 (openssh-configuration
                                  (permit-root-login #t)
                                  (allow-empty-passwords? #t)))
                        "/var/run/sshd.pid"))))

(define %test-dropbear
  (system-test
   (name "dropbear")
   (description "Connect to a running Dropbear SSH daemon.")
   (value (run-ssh-test name
                        (service dropbear-service-type
                                 (dropbear-configuration
                                  (root-login? #t)
                                  (allow-empty-passwords? #t)))
                        "/var/run/dropbear.pid"))))
