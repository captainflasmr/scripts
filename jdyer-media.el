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

;;;###autoload
(defun jdyer-media-retag-by-date ()
  "Rename images based on EXIF creation date."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((date-info (jdyer-media-get-date file))
           (prop (car date-info))
           (val (cadr date-info)))
      (when date-info
        (when (member prop '("FileModifyDate" "ModifyDate"))
          (message "Writing %s to CreateDate and DateTimeOriginal for %s" prop file)
          (shell-command (format "exiftool -all= -overwrite_original_in_place \"-CreateDate<%s\" \"-DateTimeOriginal<%s\" %s"
                                 prop prop (shell-quote-argument file))))
        (let* ((formatted-date (jdyer-media-format-date val))
               (parsed (jdyer-media--parse-filename file))
               (current-ts (cdr (assoc 'timestamp parsed)))
               (label (cdr (assoc 'label parsed)))
               (tags-raw (cdr (assoc 'tags-raw parsed)))
               (ext (cdr (assoc 'extension parsed)))
               (basedir (cdr (assoc 'directory parsed))))
          (if (not (string= formatted-date current-ts))
              (let* ((new-base (format "%s--%s" formatted-date label))
                     (new-name (if tags-raw
                                   (format "%s/%s__%s.%s" basedir new-base tags-raw ext)
                                 (format "%s/%s.%s" basedir new-base ext)))
                     (final-name new-name)
                     (counter 1))
                (while (file-exists-p final-name)
                  (setq final-name (if tags-raw
                                       (format "%s/%s%d__%s.%s" basedir new-base counter tags-raw ext)
                                     (format "%s/%s%d.%s" basedir new-base counter ext)))
                  (cl-incf counter))
                (unless (string= (expand-file-name final-name) (expand-file-name file))
                  (message "%s -> %s" file final-name)
                  (rename-file file final-name)))
            (message "#### %s : NO CHANGE" file)))))))

;;;###autoload
(defun jdyer-media-audio-convert ()
  "Convert audio to MP3."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((parsed (jdyer-media--parse-filename file))
           (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) ".mp3")))
      (jdyer-media--run-command "ffmpeg" "-hide_banner" "-loglevel" "warning" "-stats" "-y" "-i" file "-b:a" "192k" dst))))

;;;###autoload
(defun jdyer-media-audio-info ()
  "Show audio ID3 tags."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (jdyer-media--run-command "id3v2" "-l" file)))

;;;###autoload
(defun jdyer-media-picture-info ()
  "Show image metadata."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (jdyer-media--run-command "exiftool" "-g" file)))

;;;###autoload
(defun jdyer-media-video-info ()
  "Show video info using ffprobe and exiftool."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (jdyer-media--run-command "ffprobe" file)
    (jdyer-media--run-command "exiftool" file)))

;;;###autoload
(defun jdyer-media-video-to-gif ()
  "Convert video to GIF."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((parsed (jdyer-media--parse-filename file))
           (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) ".gif")))
      (jdyer-media-convert-video file dst "-vf" "fps=20,scale=800:-1:flags=lanczos" "-loop" "0"))))

;;;###autoload
(defun jdyer-media-picture-update-from-create-date ()
  "Update FileModifyDate and DateTimeOriginal from CreateDate."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (jdyer-media--run-command "exiftool" "-overwrite_original" "-FileModifyDate<CreateDate" "-DateTimeOriginal<CreateDate" file)))

;;;###autoload
(defun jdyer-media-picture-tag-rename ()
  "Rename file based on its tags and creation date."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((date-info (jdyer-media-get-date file))
           (prop (car date-info))
           (val (cadr date-info))
           (tags-out (shell-command-to-string (format "exiftool -s3 -TagsList %s" (shell-quote-argument file))))
           (tags (string-trim tags-out)))
      (when (and date-info (not (string-empty-p tags)))
        (let* ((formatted-tags (replace-regexp-in-string "/" "@" (replace-regexp-in-string "," "-" tags)))
               (formatted-date (jdyer-media-format-date val))
               (parsed (jdyer-media--parse-filename file))
               (label (cdr (assoc 'label parsed)))
               (ext (cdr (assoc 'extension parsed)))
               (basedir (cdr (assoc 'directory parsed)))
               (new-base (format "%s--%s" formatted-date label))
               (new-name (format "%s/%s__%s.%s" basedir new-base formatted-tags ext))
               (final-name new-name)
               (counter 1))
          (while (file-exists-p final-name)
            (setq final-name (format "%s/%s%d__%s.%s" basedir new-base counter formatted-tags ext))
            (cl-incf counter))
          (unless (string= (expand-file-name final-name) (expand-file-name file))
            (message "%s -> %s" file final-name)
            (rename-file file final-name)))))))

;;;###autoload
(defun jdyer-media-video-speed-up ()
  "Speed up video 2x (removes audio)."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((parsed (jdyer-media--parse-filename file))
           (timestamp (format-time-string "%Y%m%d%H%M%S"))
           (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) "-sped-" timestamp ".mp4")))
      (jdyer-media-convert-video file dst "-threads" "8" "-an" "-filter:v" "setpts=0.5*PTS" "-r" "30"))))

;;;###autoload
(defun jdyer-media-video-slow-down ()
  "Slow down video 5x (removes audio)."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((parsed (jdyer-media--parse-filename file))
           (timestamp (format-time-string "%Y%m%d%H%M%S"))
           (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) "-slow-" timestamp ".mp4")))
      (jdyer-media-convert-video file dst "-threads" "2" "-an" "-filter:v" "setpts=5*PTS" "-r" "30"))))

;;;###autoload
(defun jdyer-media-audio-normalise ()
  "Normalise audio using sox."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((parsed (jdyer-media--parse-filename file))
           (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) "-norm." (cdr (assoc 'extension parsed)))))
      (jdyer-media--run-command "sox" "--norm=0" file dst))))

;;;###autoload
(defun jdyer-media-audio-trim-silence ()
  "Trim silence from start and end of audio."
  (interactive)
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((parsed (jdyer-media--parse-filename file))
           (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) "-trim.mp3")))
      (jdyer-media--run-command "ffmpeg" "-hide_banner" "-loglevel" "warning" "-stats" "-y" "-i" file
                                "-af" "silenceremove=start_periods=1:start_duration=1:start_threshold=-60dB:detection=peak,aformat=dblp,areverse,silenceremove=start_periods=1:start_duration=1:start_threshold=-60dB:detection=peak,aformat=dblp,areverse"
                                dst))))

;;;###autoload
(defun jdyer-media-picture-crop (width height)
  "Crop image to WIDTHxHEIGHT centered."
  (interactive "nWidth: \nnHeight: ")
  (let ((dim (format "%dx%d" width height)))
    (jdyer-media-do-batch (jdyer-media-get-targets)
      (jdyer-media-convert-image file file "-resize" (concat dim "^") "-gravity" "center" "-extent" dim))))

;;;###autoload
(defun jdyer-media-video-cut (start duration)
  "Cut video from START for DURATION seconds."
  (interactive "sStart (HH:MM:SS or sec): \nsDuration (sec): ")
  (jdyer-media-do-batch (jdyer-media-get-targets)
    (let* ((parsed (jdyer-media--parse-filename file))
           (dst (concat (cdr (assoc 'directory parsed)) (cdr (assoc 'no-ext parsed)) "-cut." (cdr (assoc 'extension parsed)))))
      (jdyer-media-convert-video file dst "-ss" start "-t" duration "-c" "copy"))))

;;;###autoload
(defun jdyer-media-video-to-mp4 ()
  "Alias for video convert."
  (interactive)
  (call-interactively #'jdyer-media-video-convert))

;;;###autoload
(defun jdyer-media-completing-read-menu ()
  "Execute media command using completing-read."
  (interactive)
  (let* ((commands '(("Picture Convert" . jdyer-media-picture-convert)
                     ("Picture Crush (640px)" . jdyer-media-picture-crush)
                     ("Picture Scale (1920px)" . jdyer-media-picture-scale)
                     ("Picture Correct (Brighten)" . jdyer-media-picture-correct)
                     ("Picture Auto Colour" . jdyer-media-picture-autocolour)
                     ("Picture Crop" . jdyer-media-picture-crop)
                     ("Picture Upscale (GAN)" . jdyer-media-picture-upscale)
                     ("Picture Get Text (OCR)" . jdyer-media-picture-get-text)
                     ("Picture To PDF" . jdyer-media-picture-to-pdf)
                     ("Picture Tag (Interactive)" . jdyer-media-tag-interactive)
                     ("Picture Tag Rename" . jdyer-media-picture-tag-rename)
                     ("Picture Retag by Date" . jdyer-media-retag-by-date)
                     ("Picture Info" . jdyer-media-picture-info)
                     ("Video Convert" . jdyer-media-video-convert)
                     ("Video Shrink" . jdyer-media-video-shrink)
                     ("Video To GIF" . jdyer-media-video-to-gif)
                     ("Video Trim (Top/Tail)" . jdyer-media-video-toptail)
                     ("Video Cut" . jdyer-media-video-cut)
                     ("Video Reverse" . jdyer-media-video-reverse)
                     ("Video Speed Up" . jdyer-media-video-speed-up)
                     ("Video Slow Down" . jdyer-media-video-slow-down)
                     ("Video Extract Audio" . jdyer-media-video-extract-audio)
                     ("Video Remove Audio" . jdyer-media-video-remove-audio)
                     ("Video Info" . jdyer-media-video-info)
                     ("Audio Convert" . jdyer-media-audio-convert)
                     ("Audio Normalise" . jdyer-media-audio-normalise)
                     ("Audio Trim Silence" . jdyer-media-audio-trim-silence)
                     ("Audio Info" . jdyer-media-audio-info)))
         (choice (completing-read "Media Command: " (mapcar #'car commands) nil t))
         (func (cdr (assoc choice commands))))
    (when func
      (call-interactively func))))

;; Transient Menu

(require 'transient)

(transient-define-prefix jdyer-media-menu ()
  "Main menu for media management utilities."
  ["Image Commands"
   [("ic" "Convert" jdyer-media-picture-convert)
    ("iz" "Crush (640px)" jdyer-media-picture-crush)
    ("is" "Scale (1920px)" jdyer-media-picture-scale)
    ("iu" "Upscale (GAN)" jdyer-media-picture-upscale)]
   [("ir" "Rotate Right" jdyer-media-picture-rotate-right)
    ("il" "Rotate Left" jdyer-media-picture-rotate-left)
    ("ib" "Brighten" jdyer-media-picture-correct)
    ("ia" "Auto Colour" jdyer-media-picture-autocolour)]
   [("it" "Tag (Interactive)" jdyer-media-tag-interactive)
    ("in" "Tag Rename" jdyer-media-picture-tag-rename)
    ("id" "Retag by Date" jdyer-media-retag-by-date)
    ("if" "Update from CreateDate" jdyer-media-picture-update-from-create-date)]
   [("ip" "To PDF" jdyer-media-picture-to-pdf)
    ("io" "OCR (Get Text)" jdyer-media-picture-get-text)
    ("iC" "Crop" jdyer-media-picture-crop)
    ("ii" "Info" jdyer-media-picture-info)]]
  ["Video Commands"
   [("vc" "Convert" jdyer-media-video-convert)
    ("vs" "Shrink" jdyer-media-video-shrink)
    ("vg" "To GIF" jdyer-media-video-to-gif)
    ("va" "Extract Audio" jdyer-media-video-extract-audio)]
   [("vt" "Top/Tail (Trim)" jdyer-media-video-toptail)
    ("vk" "Cut" jdyer-media-video-cut)
    ("vr" "Reverse" jdyer-media-video-reverse)
    ("vR" "Rotate Right" jdyer-media-video-rotate-right)
    ("vL" "Rotate Left" jdyer-media-video-rotate-left)]
   [("v+" "Speed Up" jdyer-media-video-speed-up)
    ("v-" "Slow Down" jdyer-media-video-slow-down)
    ("vx" "Remove Audio" jdyer-media-video-remove-audio)
    ("vi" "Info" jdyer-media-video-info)]]
  ["Audio Commands"
   [("ac" "Convert" jdyer-media-audio-convert)
    ("an" "Normalise" jdyer-media-audio-normalise)
    ("at" "Trim Silence" jdyer-media-audio-trim-silence)
    ("ai" "Info" jdyer-media-audio-info)]]
  ["Menus"
   [("m" "Completing Read Menu" jdyer-media-completing-read-menu)]])

(provide 'jdyer-media)

;;; jdyer-media.el ends here
