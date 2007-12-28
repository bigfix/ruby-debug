;; -*- emacs-lisp -*-
(load-file "./elk-test.el")

;; FIXME? Should we use "require 'rdebug" here.
;; Would have to prepend . to load-path. 
(load-file "./rdebug.el")
(load-file "./rdebug-core.el")

(defvar last-gud-call nil
  "Value of the last gud-call")

;; Redefine functions to make them harmless for testing
(defun gud-call (command)
  (setq last-gud-call command))

(deftest "rdebug-goto-frame-test"
  (let ((buf (generate-new-buffer "testing")))
    (save-excursion
      (switch-to-buffer buf)
      (insert "#0 ERB.result(b#Binding) at line /usr/lib/ruby/1.8/erb.rb:736\n")
      (insert "#1 Listings.build at line erbtest.rb:24\n")
      (insert "#2 at line erbtest.rb:33\n")
      (insert "#10 Listings.build at line erbtest.rb:23")
      (goto-char (point-min))
      (setq last-gud-call nil)
      (setq rdebug-goto-entry-acc "")

      ;; --------------------
      ;; The tests

      (rdebug-goto-frame-n-internal "5")
      (assert-equal nil last-gud-call)
      (rdebug-goto-frame-n-internal "1")
      (assert-equal "frame 1" last-gud-call)
      (rdebug-goto-frame-n-internal "0")
      (assert-equal "frame 10" last-gud-call))
    (kill-buffer buf)))


;; -------------------------------------------------------------------
;; Check breakpoint toggle commands
;;

(deftest "rdebug-toggle-breakpoints"
  (let ((buf (generate-new-buffer "*rdebug-breakpoints-test.rb*")))
    (save-excursion
      (switch-to-buffer buf)
      (insert "Num Enb What\n")
      (insert "  1 y   at c:/test.rb:10\n")
      (insert "  2 n   at c:/test.rb:11\n")
      (insert "  3 y   at c:/test.rb:12\n")
      (insert "  4 y   at c:/test.rb:13\n"))
    (setq gud-target-name "test.rb")

    ;; ----------
    ;; Toggle break point
    (assert-equal 4 (length (rdebug-all-breakpoints)))

    ;; ----------
    ;; Toggle break point

    ;; Add new.
    (rdebug-toggle-source-breakpoint "c:/test.rb" 20)
    (assert-equal "break c:/test.rb:20" last-gud-call)
    ;; Delete enabled.
    (rdebug-toggle-source-breakpoint "c:/test.rb" 10)
    (assert-equal "delete 1" last-gud-call)
    ;; Delete disabled.
    (rdebug-toggle-source-breakpoint "c:/test.rb" 11)
    (assert-equal "delete 2" last-gud-call)

    ;; ----------
    ;; Toggle enable/disable.

    ;; Add new.
    (rdebug-toggle-source-breakpoint-enabled "c:/test.rb" 30)
    (assert-equal "break c:/test.rb:30" last-gud-call)

    ;; Toggle enabled.
    (rdebug-toggle-source-breakpoint-enabled "c:/test.rb" 10)
    (assert-equal "disable 1" last-gud-call)
    ;; Toggle disabled.
    (rdebug-toggle-source-breakpoint-enabled "c:/test.rb" 11)
    (assert-equal "enable 2" last-gud-call)))


;; -------------------------------------------------------------------
;; Build and run the test suite.
;;

(build-suite "rdebug-core-suite"
	     "rdebug-goto-frame-test"
	     "rdebug-toggle-breakpoints")
(run-elk-test "rdebug-core-suite"
              "test some rdebug-core code")