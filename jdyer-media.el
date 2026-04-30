;;; jdyer-media.el --- Media management utilities  -*- lexical-binding: t; -*-

;; Author: James Dyer <james@dyerdwelling.family>
;; Keywords: media, image, video, automation
;; Package-Requires: ((emacs "27.1") (cl-lib "0.5"))

;;; Commentary:
;; This package provides Emacs Lisp implementations of James Dyer's media
;; utility scripts (Picture* and Video*), replacing the bash implementations.
;; It relies on external tools: exiftool, imagemagick (magick), ffmpeg,
;; tesseract, and realesrgan-ncnn-vulkan.

;;; Code:

(require 'cl-lib)
(require 'dired)

(defgroup jdyer-media nil
  "Media management utilities."
  :group 'media)

(defcustom jdyer-media-trash-command "trash-put"
  "Command to use for trashing files."
  :type 'string
  :group 'jdyer-media)

;;; Core Variables & Parsing

(defun jdyer-media--parse-filename (file)
  "Parse media filename YYYYMMDDHHMMSS--description__tag1@tag2.ext.
Returns an alist with keys: directory, filename, extension, no-ext,
no-tag, timestamp, label, tags-raw, tags, keywords."
  (let* ((file (expand-file-name file))
         (directory (file-name-directory file))
         (filename (file-name-nondirectory file))
         (extension (file-name-extension filename))
         (no-ext (file-name-sans-extension filename))
         ;; Split by __ to get description and tags
         (parts (split-string no-ext "__"))
         (desc-part (car parts))
         (tags-raw (cadr parts))
         ;; Split description by -- to get timestamp and label
         (desc-subparts (split-string desc-part "--"))
         (has-timestamp (and (> (length desc-subparts) 1)
                            (string-match-p "^[0-9]\\{14\\}$" (car desc-subparts))))
         (timestamp (if has-timestamp (car desc-subparts) ""))
         (label (if has-timestamp (cadr desc-subparts) (car desc-subparts)))
         (no-tag (if has-timestamp 
                     (format "%s--%s.%s" timestamp label extension)
                   (format "%s.%s" label extension)))
         ;; Parse tags
         (tags (when tags-raw
                 (replace-regexp-in-string "[-_]" " " (replace-regexp-in-string "@" " " tags-raw))))
         (keywords (when tags
                     (delete-dups (sort (split-string tags " " t) #'string<)))))
    `((directory . ,directory)
      (filename . ,filename)
      (extension . ,extension)
      (no-ext . ,no-ext)
      (no-tag . ,no-tag)
      (timestamp . ,timestamp)
      (label . ,label)
      (tags-raw . ,tags-raw)
      (tags . ,tags)
      (keywords . ,keywords))))

(defun jdyer-media-get-date (file)
  "Get creation date from FILE using exiftool.
Tries CreateDate, DateTimeOriginal, ModifyDate, and FileModifyDate."
  (let ((props '("CreateDate" "DateTimeOriginal" "ModifyDate" "FileModifyDate"))
        (result nil))
    (cl-loop for prop in props
             until result
             do (let ((val (shell-command-to-string
                            (format "exiftool -s3 -%s %s"
                                    prop (shell-quote-argument (expand-file-name file))))))
                  (setq val (string-trim val))
                  (unless (string-empty-p val)
                    (setq result (list prop val)))))
    result))

(defun jdyer-media-format-date (date-string)
  "Format exiftool date (YYYY:MM:DD HH:MM:SS) to YYYYMMDDHHMMSS."
  (let ((cleaned (replace-regexp-in-string "[: ]" "" date-string)))
    (if (string-match "^\\([0-9]\\{14\\}\\)" cleaned)
        (match-string 1 cleaned)
      cleaned)))

;;; Internal Process Wrappers

(defun jdyer-media--run-command (cmd &rest args)
  "Run CMD with ARGS and return exit code."
  (let ((full-cmd (mapconcat #'shell-quote-argument (cons cmd args) " ")))
    (message "Running: %s" full-cmd)
    (shell-command full-cmd)))

(defun jdyer-media--preserve-metadata (src dst)
  "Copy metadata from SRC to DST and preserve timestamp."
  (jdyer-media--run-command "exiftool" "-overwrite_original_in_place" "-TagsFromFile" src dst)
  (set-file-times dst (file-attribute-modification-time (file-attributes src))))

(defun jdyer-media--trash (file)
  "Move FILE to trash."
  (if (executable-find jdyer-media-trash-command)
      (jdyer-media--run-command jdyer-media-trash-command file)
    (move-file-to-trash file)))

;;; High-level Conversion Helpers (replacing convert_it*)

(defun jdyer-media-convert-image (src dst &rest magick-args)
  "Convert image SRC to DST using MAGICK-ARGS.
Preserves metadata and moves SRC to trash."
  (let ((tmp (make-temp-file "jdyer-media-" nil (concat "." (file-name-extension dst)))))
    (unwind-protect
        (progn
          (apply #'jdyer-media--run-command "magick" src (append magick-args (list tmp)))
          (jdyer-media--preserve-metadata src tmp)
          (copy-file tmp dst t t t t)
          (unless (string= (expand-file-name src) (expand-file-name dst))
            (jdyer-media--trash src)))
      (when (file-exists-p tmp) (delete-file tmp)))))

(defun jdyer-media-convert-image-copy (src dst &rest magick-args)
  "Convert image SRC to DST using MAGICK-ARGS.
Preserves metadata, keeps SRC."
  (let ((tmp (make-temp-file "jdyer-media-" nil (concat "." (file-name-extension dst)))))
    (unwind-protect
        (progn
          (apply #'jdyer-media--run-command "magick" src (append magick-args (list tmp)))
          (jdyer-media--preserve-metadata src tmp)
          (copy-file tmp dst t t t t))
      (when (file-exists-p tmp) (delete-file tmp)))))

(defun jdyer-media-convert-video (src dst &rest ffmpeg-args)
  "Convert video SRC to DST using FFMPEG-ARGS.
Preserves metadata."
  (let ((tmp (make-temp-file "jdyer-media-" nil (concat "." (file-name-extension dst)))))
    (unwind-protect
        (progn
          (let ((cmd-args (append (list "-hide_banner" "-loglevel" "warning" "-stats" "-y" "-i" src "-map_metadata" "0" "-threads" "8")
                                  ffmpeg-args
                                  (list tmp))))
            (apply #'jdyer-media--run-command "ffmpeg" cmd-args))
          (set-file-times tmp (file-attribute-modification-time (file-attributes src)))
          (copy-file tmp dst t t t t))
      (when (file-exists-p tmp) (delete-file tmp)))))

(defun jdyer-media-convert-gan (src dst &rest gan-args)
  "Upscale image SRC to DST using realesrgan-ncnn-vulkan with GAN-ARGS.
Preserves metadata and moves SRC to trash."
  (let ((tmp (make-temp-file "jdyer-media-" nil (concat "." (file-name-extension dst)))))
    (unwind-protect
        (progn
          (let ((cmd-args (append gan-args (list "-i" src "-o" tmp))))
            (apply #'jdyer-media--run-command "realesrgan-ncnn-vulkan" cmd-args))
          (jdyer-media--preserve-metadata src tmp)
          (copy-file tmp dst t t t t)
          (unless (string= (expand-file-name src) (expand-file-name dst))
            (jdyer-media--trash src)))
      (when (file-exists-p tmp) (delete-file tmp)))))

;;; Batch / Dired Integration

(defun jdyer-media-get-targets ()
  "Get list of files to process. 
If in dired, use marked files or file at point. Otherwise ask for file."
  (if (derived-mode-p 'dired-mode)
      (dired-get-marked-files)
    (list (read-file-name "Process file: "))))

(defmacro jdyer-media-do-batch (files &rest body)
  "Run BODY for each file in FILES, binding 'file' to current file."
  (declare (indent 1))
  `(dolist (file ,files)
     (let ((default-directory (file-name-directory file)))
       ,@body)))

;;; Specific Commands

;;;###autoload
(defun jdyer-media-picture-convert ()
  "Convert images to JPG."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((parsed (jdyer-media--parse-filename file))
           (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) ".jpg")))
      (if (string-suffix-p ".svg" file t)
          (jdyer-media-convert-image-copy file dst "-density" "300" "-auto-orient" "-strip")
        (jdyer-media-convert-image file dst "-auto-orient" "-strip")))))

;;;###autoload
(defun jdyer-media-picture-crush ()
  "Resize images to 640px."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (jdyer-media-convert-image file file "-auto-orient" "-strip" "-quality" "50%" "-resize" "640x>" "-resize" "x640>")))

;;;###autoload
(defun jdyer-media-picture-scale ()
  "Resize images to 1920px."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (jdyer-media-convert-image file file "-auto-orient" "-strip" "-quality" "50%" "-resize" "1920x>" "-resize" "x1920>")))

;;;###autoload
(defun jdyer-media-picture-rotate-right ()
  "Rotate images 90 degrees clockwise."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (jdyer-media-convert-image file file "-rotate" "90")))

;;;###autoload
(defun jdyer-media-picture-rotate-left ()
  "Rotate images 90 degrees counter-clockwise."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (jdyer-media-convert-image file file "-rotate" "-90")))

;;;###autoload
(defun jdyer-media-picture-correct ()
  "Brighten images (120% modulate)."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (jdyer-media-convert-image file file "-modulate" "120,100,100")))

;;;###autoload
(defun jdyer-media-video-convert ()
  "Convert videos to MP4 (h264/aac)."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((parsed (jdyer-media--parse-filename file))
           (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) ".mp4")))
      (jdyer-media-convert-video file dst "-c:a" "aac" "-c:v" libx264 "-crf" "23"))))

;;;###autoload
(defun jdyer-media-video-shrink ()
  "Resize videos to fit 960x960."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((parsed (jdyer-media--parse-filename file))
           (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) ".mp4")))
      (jdyer-media-convert-video file dst 
                                 "-vf" "scale='min(960,iw)':'min(960,ih)':force_original_aspect_ratio=decrease"
                                 "-vcodec" "libx264" "-crf" "28" "-preset" "medium" "-movflags" "+faststart"))))

;;;###autoload
(defun jdyer-media-video-extract-audio ()
  "Extract audio from videos as WAV."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((parsed (jdyer-media--parse-filename file))
           (timestamp (format-time-string "%Y%m%d%H%M%S"))
           (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) "-" timestamp ".wav")))
      (jdyer-media-convert-video file dst "-vn" "-q:a" "0" "-map" "a"))))

;;;###autoload
(defun jdyer-media-video-toptail (trim-start trim-end)
  "Trim video from start and end."
  (interactive "nTrim from start (sec): \nnTrim from end (sec): ")
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((duration-str (shell-command-to-string
                          (format "ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 %s"
                                  (shell-quote-argument file))))
           (duration (floor (string-to-number duration-str)))
           (end-time (- duration trim-end))
           (parsed (jdyer-media--parse-filename file))
           (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) "-trimmed." (cdr (assoc 'extension parsed)))))
      (if (<= end-time trim-start)
          (message "Error: Trim amount exceeds duration for %s" file)
        (jdyer-media-convert-video file dst "-ss" (number-to-string trim-start) "-t" (number-to-string end-time) "-c" "copy")))))

;;;###autoload
(defun jdyer-media-picture-upscale ()
  "Upscale images using realesrgan-x4plus."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((parsed (jdyer-media--parse-filename file))
           (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) ".jpg")))
      (jdyer-media-convert-gan file dst "-n" "realesrgan-x4plus" "-j" "8:8:8" "-f" "jpg"))))

;;;###autoload
(defun jdyer-media-picture-get-text ()
  "Extract text from images using tesseract OCR."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((parsed (jdyer-media--parse-filename file))
           (out-base (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)))))
      (jdyer-media--run-command "tesseract" "-l" "eng" file out-base))))

;;;###autoload
(defun jdyer-media-picture-autocolour ()
  "Auto-level image colors."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (jdyer-media-convert-image file file "-auto-level")))

;;;###autoload
(defun jdyer-media-video-remove-audio ()
  "Remove audio from videos."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (jdyer-media-convert-video file file "-an" "-c:v" "copy")))

;;;###autoload
(defun jdyer-media-video-reverse ()
  "Reverse video and audio."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((parsed (jdyer-media--parse-filename file))
           (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) "-reversed." (cdr (assoc 'extension parsed)))))
      (jdyer-media-convert-video file dst "-vf" "reverse" "-af" "areverse"))))

;;;###autoload
(defun jdyer-media-video-rotate-right ()
  "Rotate video 90 degrees clockwise."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (jdyer-media-convert-video file file "-vf" "transpose=1")))

;;;###autoload
(defun jdyer-media-video-rotate-left ()
  "Rotate video 90 degrees counter-clockwise."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (jdyer-media-convert-video file file "-vf" "transpose=2")))

;;;###autoload
(defun jdyer-media-picture-to-pdf ()
  "Convert images to PDF."
  (interactive)
  (let ((targets (jdyer-media-get-targets)))
    (if (= (length targets) 1)
        (let* ((file (car targets))
               (parsed (jdyer-media--parse-filename file))
               (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) ".pdf")))
          (jdyer-media--run-command "magick" file dst))
      (let ((dst (read-file-name "Output PDF: ")))
        (apply #'jdyer-media--run-command "magick" (append targets (list dst)))))))

;;;###autoload
(defun jdyer-media-tag-interactive (tags)
  "Interactively tag selected media files.
TAGS is a comma-separated string or list of tags."
  (interactive (list (completing-read-multiple "Tags (comma separated): " nil)))
  (let* ((tag-list (if (stringp tags) (split-string tags "," t) tags))
         (tag-str (mapconcat #'identity tag-list ","))
         (hier-tag-str (replace-regexp-in-string "@" "/" tag-str))
         (keywords (delete-dups (sort (mapcan (lambda (t) (split-string (replace-regexp-in-string "@" " " t) " " t)) tag-list) #'string<)))
         (keyword-str (mapconcat #'identity keywords ",")))
    (jdyer-media-do-batch (jdyer-media-get-targets)
      (message "Tagging %s with %s" file tag-str)
      (jdyer-media--run-command "exiftool" "-overwrite_original_in_place"
                                (format "-TagsList=%s" hier-tag-str)
                                (format "-XMP-microsoft:LastKeywordXMP=%s" hier-tag-str)
                                (format "-HierarchicalSubject=%s" (replace-regexp-in-string "/" "|" hier-tag-str))
                                (format "-XPKeywords=%s" keyword-str)
                                (format "-Subject=%s" keyword-str)
                                (format "-Keywords=%s" keyword-str)
                                file))))

(provide 'jdyer-media)
;;; jdyer-media.el ends here
