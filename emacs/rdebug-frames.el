;;; rdebug-frames.el --- Ruby debugger frames buffer

;; Copyright (C) 2008 Rocky Bernstein (rocky@gnu.org)
;; Copyright (C) 2008 Anders Lindgren

;; $Id$

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; This file contains code dealing with the frames secondary buffer.
(require 'rdebug-dbg)

(defun rdebug-display-stack-buffer ()
  "Display the rdebug stack buffer."
  (interactive)
  (rdebug-display-secondary-buffer "stack"))

(defvar rdebug-frames-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [mouse-1] 'rdebug-goto-stack-frame-mouse)
    (define-key map [mouse-2] 'rdebug-goto-stack-frame-mouse)
    (define-key map [mouse-3] 'rdebug-goto-stack-frame-mouse)
    (define-key map [(control m)] 'rdebug-goto-stack-frame)
    (define-key map "0" 'rdebug-goto-frame-n)
    (define-key map "1" 'rdebug-goto-frame-n)
    (define-key map "2" 'rdebug-goto-frame-n)
    (define-key map "3" 'rdebug-goto-frame-n)
    (define-key map "4" 'rdebug-goto-frame-n)
    (define-key map "5" 'rdebug-goto-frame-n)
    (define-key map "6" 'rdebug-goto-frame-n)
    (define-key map "7" 'rdebug-goto-frame-n)
    (define-key map "8" 'rdebug-goto-frame-n)
    (define-key map "9" 'rdebug-goto-frame-n)
    (rdebug-populate-secondary-buffer-map map)

    ;; --------------------
    ;; The "Stack window" submenu.
    (let ((submenu (make-sparse-keymap)))
      (define-key-after map [menu-bar debugger stack]
        (cons "Stack window" submenu)
        'placeholder))

    (define-key map [menu-bar debugger stack goto]
      '(menu-item "Goto frame" rdebug-goto-stack-frame))
    map)
  "Keymap to navigate rdebug stack frames.")

(defun rdebug-frames-mode ()
  "Major mode for displaying the stack trace in the `rdebug' Ruby debugger.

\\{rdebug-frames-mode-map}"
  (interactive)
  ;; (kill-all-local-variables)
  (setq major-mode 'rdebug-frames-mode)
  (setq mode-name "RDEBUG Stack Frames")
  (set (make-local-variable 'rdebug-secondary-buffer) t)
  (use-local-map rdebug-frames-mode-map)
  ;; (set (make-local-variable 'font-lock-defaults)
  ;;     '(gdb-locals-font-lock-keywords))
  (run-mode-hooks 'rdebug-frames-mode-hook))

(defun rdebug--setup-stack-buffer (buf comint-buffer)
  "Detects stack frame lines and sets up mouse navigation."
  (rdebug-debug-enter "rdebug--setup-stack-buffer"
    (with-current-buffer buf
      (let ((inhibit-read-only t)
            ;; position in stack buffer of selected frame
            (current-frame-point nil))
        (rdebug-frames-mode)
        (set (make-local-variable 'gud-comint-buffer) comint-buffer)
        (goto-char (point-min))
        (while (not (eobp))
          (let* ((b (line-beginning-position)) (e (line-end-position))
                 (s (buffer-substring b e)))
            (when (string-match rdebug--stack-frame-1st-regexp s)
              (add-text-properties
               (+ b (match-beginning 2)) (+ b (match-end 2))
               (list 'face font-lock-constant-face
                     'font-lock-face font-lock-constant-face))
              ;; Not all stack frames are on one line.
              ;; handle those that are.
              (when (string-match rdebug--stack-frame-regexp s)
                (add-text-properties
                 (+ b (match-beginning 4)) (+ b (match-end 4))
                 (list 'face font-lock-comment-face
                       'font-lock-face font-lock-comment-face))
                (add-text-properties
                 (+ b (match-beginning 5)) (+ b (match-end 5))
                 (list 'face font-lock-constant-face
                       'font-lock-face font-lock-constant-face)))

              (when (string= (substring s (match-beginning 1) (match-end 1))
                             "-->")
                ;; highlight the currently selected frame
                (add-text-properties b e
                                     (list 'face 'bold
                                           'font-lock-face 'bold))
		(setq overlay-arrow-position (make-marker))
		(set-marker overlay-arrow-position (point))
		(setq current-frame-point (point)))
              (add-text-properties b e
                                   (list 'mouse-face 'highlight
                                         'keymap rdebug-frames-mode-map))
              (let ((fn-str (substring s (match-beginning 3) (match-end 3)))
                    (fn-start (+ b (match-beginning 3))))
                (if (string-match "\\([^(]+\\)(" fn-str)
                    (add-text-properties
                     (+ fn-start (match-beginning 1))
                     (+ fn-start (match-end 1))
                     (list 'face font-lock-function-name-face
                           'font-lock-face font-lock-function-name-face))))))
          ;; remove initial '   '  or '-->'
          (beginning-of-line)
          (delete-char 3)
          (forward-line)
          (beginning-of-line))
        (when current-frame-point
          (goto-char current-frame-point))))))

(defun rdebug-goto-stack-frame (pt)
  "Show the rdebug stack frame corresponding at PT in the rdebug stack buffer."
  (interactive "d")
  (save-excursion
    (goto-char pt)
    (let ((s (concat "-->" (buffer-substring (line-beginning-position)
                                             (line-end-position))))
	  (s2 (if (= (line-number-at-pos (line-end-position 2))
                     (line-number-at-pos (point-max)))
		  nil
		;;else
                (buffer-substring (line-beginning-position 2)
                                  (line-end-position 2)))))
      (when (or (string-match rdebug--stack-frame-regexp s)
		;; need to match 1st line last to get the match position right
		(and s2 (string-match rdebug--stack-frame-2nd-regexp s2)
		     (string-match rdebug--stack-frame-1st-regexp s)))
        (let ((frame (substring s (match-beginning 2) (match-end 2))))
          (gud-call (concat "frame " frame)))))))

(defun rdebug-goto-stack-frame-mouse (event)
  "Show the rdebug stack frame under the mouse in the rdebug stack buffer."
  (interactive "e")
  (with-current-buffer (window-buffer (posn-window (event-end event)))
    (rdebug-goto-stack-frame (posn-point (event-end event)))))

;; The following is split in two to facilitate debugging.
(defun rdebug-goto-frame-n-internal (keys)
  (if (and (stringp keys)
           (= (length keys) 1))
      (progn
        (setq rdebug-goto-entry-acc (concat rdebug-goto-entry-acc keys))
        ;; Try to find the longest suffix.
        (let ((acc rdebug-goto-entry-acc))
          (while (not (string= acc ""))
            (if (not (rdebug-goto-entry-try acc))
                (setq acc (substring acc 1))
              (gud-call (format "frame %s" acc))
              ;; Break loop.
              (setq acc "")))))
    (message "`rdebug-goto-frame-n' must be bound to a number key")))

(defun rdebug-goto-frame-n ()
  "Go to the frame number indicated by the accumulated numeric keys just entered.

This function is usually bound to a numeric key in a 'frame'
secondary buffer. To go to an entry above 9, just keep entering
the number. For example, if you press 1 and then 9, frame 1 is selected
\(if it exists) and then frame 19 (if that exists). Entering any
non-digit will start entry number from the beginning again."
  (interactive)
  (if (not (eq last-command 'rdebug-goto-frame-n))
      (setq rdebug-goto-entry-acc ""))
  (rdebug-goto-frame-n-internal (this-command-keys)))


(provide 'rdebug-frames)