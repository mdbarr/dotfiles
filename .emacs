;; .emacs
;; package dependencies:
;;   afternoon-theme
;;   all-the-icons
;;   multi-web-mode
;;   powerline
;;   vue-html-mode
;;   vue-mode


;; Melpa
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/") t)
(package-initialize)

;; Menu Bars are not for winners
(menu-bar-mode -1)
;; Disable backup
(setq backup-inhibited t)
;; Disable auto save
(setq auto-save-default nil)
;; Disable lock files
(setq create-lockfiles nil)

;; No Tabs and default indents
(setq-default indent-tabs-mode nil)
(setq tab-width 2)
(setq css-indent-offset 2)
(setq-default c-basic-offset 2)
(setq mode-require-final-newline nil)
(setq cperl-indent-level 2)

(require 'cl)
(require 'cc-mode)

(require 'multi-web-mode)
(setq mweb-default-major-mode 'html-mode)
(setq mweb-tags
      '((js-mode  "<script[^>]*>" "</script>")
        (css-mode "<style[^>]*>" "</style>")))
(setq mweb-filename-extensions '("html" "htm"))
(setq mweb-submode-indent-offset 0)
(multi-web-global-mode 1)

(setq require-final-newline t)
(setq mode-require-final-newline t)

;; Groovy
(add-hook 'groovy-mode-hook
          (lambda ()
            (c-set-offset 'label 2)))

;; Typescript
(setq-default typescript-indent-level 2)

;; JavaScript indentatioon
(setq js-indent-level 2)

(defun js--proper-indentation-custom (parse-status)
  "Return the proper indentation for the current line according to PARSE-STATUS argument."
  (save-excursion
    (back-to-indentation)
    (cond ((nth 4 parse-status)    ; inside comment
           (js--get-c-offset 'c (nth 8 parse-status)))
          ((nth 3 parse-status) 0) ; inside string
          ((eq (char-after) ?#) 0)
          ((save-excursion (js--beginning-of-macro)) 4)
          ;; Indent array comprehension continuation lines specially.
          ((let ((bracket (nth 1 parse-status))
                 beg)
             (and bracket
                  (not (js--same-line bracket))
                  (setq beg (js--indent-in-array-comp bracket))
                  ;; At or after the first loop?
                  (>= (point) beg)
                  (js--array-comp-indentation bracket beg))))
          ((js--ctrl-statement-indentation))
          ((nth 1 parse-status)
           ;; A single closing paren/bracket should be indented at the
           ;; same level as the opening statement. Same goes for
           ;; "case" and "default".
           (let ((same-indent-p (looking-at "[]})]"))
                 (switch-keyword-p (looking-at "default\\_>\\|case\\_>[^:]"))
                 (continued-expr-p (js--continued-expression-p))
                 (original-point (point))
                 (open-symbol (nth 1 parse-status)))
             (goto-char (nth 1 parse-status)) ; go to the opening char
             (skip-syntax-backward " ")
             (when (eq (char-before) ?\)) (backward-list))
             (back-to-indentation)
             (js--maybe-goto-declaration-keyword-end parse-status)
             (let* ((in-switch-p (unless same-indent-p
                                   (looking-at "\\_<switch\\_>")))
                    (same-indent-p (or same-indent-p
                                       (and switch-keyword-p
                                            in-switch-p)))
                    (indent
                     (cond (same-indent-p
                            (current-column))
                           (continued-expr-p
                            (goto-char original-point)
                            ;; Go to beginning line of continued expression.
                            (while (js--continued-expression-p)
                              (forward-line -1))
                            ;; Go to the open symbol if it appears later.
                            (when (> open-symbol (point))
                              (goto-char open-symbol))
                            (back-to-indentation)
                            (+ (current-column)
                               js-indent-level
                               js-expr-indent-offset))
                           (t
                            (+ (current-column) js-indent-level
                               (pcase (char-after (nth 1 parse-status))
                                 (?\( js-paren-indent-offset)
                                 (?\[ js-square-indent-offset)
                                 (?\{ js-curly-indent-offset)))))))
               (if in-switch-p
                   (+ indent js-switch-indent-offset)
                 indent))))
          ((js--continued-expression-p)
           (+ js-indent-level js-expr-indent-offset))
          (t 0))))

(advice-add 'js--proper-indentation :override 'js--proper-indentation-custom)

;; JS2 + Refactor Mode
;;(require 'js2-mode)
;;(require 'js2-refactor)
;;(add-hook 'js2-mode-hook #'js2-refactor-mode)
;;(add-to-list 'auto-mode-alist '("\\.js\\'" . js2-mode))
;;(setq js2-basic-offset 2)

;; Line numbers
(global-linum-mode)
(set-face-attribute 'default nil :background "color-16")
(set-face-attribute 'linum nil :foreground "Gray30" :background "color-16")
(defadvice linum-update-window (around linum-dynamic activate)
  (let* ((w (length (number-to-string
                     (count-lines (point-min) (point-max)))))
         (linum-format (concat "%" (number-to-string w) "d\u2502 ")))
    ad-do-it))

;; Auto delete trailing whitespace on save
(add-hook 'before-save-hook 'delete-trailing-whitespace)

;; Autorevert file buffers
(global-auto-revert-mode)

;; Revert alias and revert all file buffers
(defalias 'revert 'revert-buffer)

(defun revert-all-file-buffers ()
    "Refresh all open file buffers without confirmation.
Buffers in modified (not yet saved) state in emacs will not be reverted. They
will be reverted though if they were modified outside emacs.
Buffers visiting files which do not exist any more or are no longer readable
will be killed."
    (interactive)
    (dolist (buf (buffer-list))
      (let ((filename (buffer-file-name buf)))
        ;; Revert only buffers containing files, which are not modified;
        ;; do not try to revert non-file buffers like *Messages*.
        (when (and filename
                   (not (buffer-modified-p buf)))
          (if (file-readable-p filename)
              ;; If the file exists and is readable, revert the buffer.
              (with-current-buffer buf
                (revert-buffer :ignore-auto :noconfirm))
            ;; Otherwise, kill the buffer.
            (let (kill-buffer-query-functions) ; No query done when killing buffer
              (kill-buffer buf)
              (message "Killed non-existing/unreadable file buffer: %s" filename))))))
      (message "Finished reverting buffers containing unmodified files."))

;; UUID Insertion
(require 'subr-x)

(defun uuid ()
  (interactive)
  (insert
   (string-trim
    (shell-command-to-string "uuid"))))

;; Afernoon Theme (afternoon-theme)
(load-theme 'afternoon t)
(set-face-attribute 'mode-line-buffer-id nil :foreground "DeepSkyBlue1")

;; Powerline
(require 'powerline)
(powerline-default-theme)
(set-face-attribute 'mode-line nil :background "Gray25")
(set-face-attribute 'powerline-active1 nil :background "#175993" :box nil)
(set-face-attribute 'powerline-active2 nil :background "Gray25" :box nil)
