;;; -*- Mode: Lisp -*-

;;; This software is in the public domain and is
;;; provided with absolutely no warranty.

(in-package #:wunderground)

(defvar *geo-lookup-url*
  "http://api.wunderground.com/auto/wui/geo/GeoLookupXML/index.xml")

(defvar *current-weather-url*
  "http://api.wunderground.com/auto/wui/geo/WXCurrentObXML/index.xml")

(defun parse-xml (xml)
  (cxml:parse xml (cxml:make-whitespace-normalizer (stp:make-builder))))

(defun find-child (local-name xml)
  (stp:find-child-if (lambda (child)
                       (when (typep child 'stp:element)
                         (equal (stp:local-name child)
                                local-name)))
                     xml))

(defun find-value (name xml &key integer)
  (let* ((child (find-child name xml))
         (value (and child (stp:string-value child))))
    (if (and (stringp value) integer)
        (values
         (parse-integer value :junk-allowed t))
        value)))

(defun find-child-path (xml &rest local-names)
  (loop for name in local-names
        for node = (find-child name xml) then (find-child name node)
        while node
        finally (return node)))

(defun query-station (id)
  (parse-weather
   (find-child "current_observation"
               (parse-xml (drakma:http-request *current-weather-url*
                                               :parameters `(("query" . ,id)))))))

(defclass current-weather ()
  ((name :initarg :name
         :initform nil
         :accessor name)
   (temperature :initarg :temperature
                :initform nil
                :accessor temperature)
   (humidity :initarg :humidity
             :initform nil
             :accessor humidity)
   (wind-speed :initarg :wind-speed
               :initform nil
               :accessor wind-speed)
   (wind-direction :initarg :wind-direction
                   :initform nil
                   :accessor wind-direction)
   (last-updated :initarg :last-updated
                 :initform nil
                 :accessor last-updated)))

(defun get-city-name (xml)
  (stp:string-value
   (find-child-path xml "observation_location" "city")))

(defun mph-to-km/h (mph)
  (* mph 1.609344))

(defun get-last-updated (xml)
  (ppcre:register-groups-bind (date)
      ("^Last Updated on (\\w+ \\d+, \\d+:\\d+ (?:A|P)M).*$"
       (find-value "observation_time" xml))
    date))

(defun parse-weather (xml)
  (make-instance 'current-weather
        :name (get-city-name xml)
        :temperature (find-value "temp_c" xml :integer t)
        :humidity (find-value "relative_humidity" xml :integer t)
        :wind-speed (mph-to-km/h (find-value "wind_mph" xml :integer t))
        :wind-direction (find-value "wind_dir" xml)
        :last-updated (get-last-updated xml)))

(defun print-weather (weather)
  (format nil "~a °C, ~a% humidity; Wind: ~a ~,2f km/h. Updated: ~a"
          (temperature weather)
          (humidity weather)
          (wind-direction weather)
          (wind-speed weather)
          (last-updated weather)))
