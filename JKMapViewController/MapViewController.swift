// add this setting
// info.plist
// Privacy - Location Always and When In Use Usage Description
// Privacy - Location When In Use Usage Description

/* 기능
 1. 지도에 현재 위치 표현
 2. 지도 클릭시 사진 표시
*/

import UIKit
import MapKit

open class MapViewController: UIViewController {
    public var mapView: MKMapView!
    public var longPressGestureRecogn: UILongPressGestureRecognizer!
    public var locationManager:CLLocationManager!
    public var myLocationsInfo: [Location] = []    
    
    static var cnt: Int = 0
    public var imageIcon: UIImage!
    public var isStopDraw = false // true면 맵에 그리는 것을 중지하는 것 && annotation표시 불가(맵 드래그로 이동 가능)
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    private func setup() {
        imageIcon = UIImage(named: "Footprint.png")
        
        mapView = MKMapView()
        self.view.addSubview(mapView)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        
        mapView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        mapView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        mapView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        mapView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        
        setLocationManager()
        mapView.delegate = self
        mapView.showsUserLocation = true
        
        // 클릭하여 pin 생성, 위 addPin액션 메서드와 연결
        longPressGestureRecogn = UILongPressGestureRecognizer(target: self, action: #selector(self.addPin(press:)))
        longPressGestureRecogn.minimumPressDuration = 0.0001
        mapView.addGestureRecognizer(longPressGestureRecogn)
    }
    
    func setLocationManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
    }
    
//     맵 클릭시, 그 위에 핀 놓기 : storyboard에서 Long Press Gesture Recognizer생성
     @objc func addPin(press:UILongPressGestureRecognizer) {
        
         let location = press.location(in: self.mapView)
         let locCoord = self.mapView.convert(location, toCoordinateFrom: self.mapView)
         let annotation = MKPointAnnotation()

         annotation.coordinate = locCoord
         getAlert(annotation: annotation)

     }

    func getAlert(annotation: MKPointAnnotation) {
        let alert = UIAlertController(title: "input the location name", message: "what is the this information?", preferredStyle: .alert)

        let cancel = UIAlertAction(title: "cancel", style: .cancel)

        alert.addTextField{(tf) in
            tf.placeholder = "mark name"
        }

        let ok = UIAlertAction(title: "ok", style: .default){(_) in
            // self.mapView.removeAnnotations(mapView.annotations)
            annotation.title = alert.textFields?[0].text

            // save image information in realm DB
            let latitude: Double = annotation.coordinate.latitude
            let longitude: Double = annotation.coordinate.longitude
            let img = self.imageIcon

            for item in self.myLocationsInfo {
                if item.imgLatitude != -1 {
                    continue
                } else {
                    item.img = img?.jpegData(compressionQuality: 0.9)
                    item.imgLatitude = latitude
                    item.imgLongitude = longitude
                    break
                }
            }

            self.mapView.addAnnotation(annotation)
        }

        alert.addAction(ok)
        alert.addAction(cancel)
        present(alert, animated: true)
    }
    
}

// MARK: - map
extension MapViewController: MKMapViewDelegate {
    
    public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let polylineRenderer = MKPolylineRenderer(overlay: overlay)
        polylineRenderer.strokeColor = .blue
        polylineRenderer.lineWidth = 4
        return polylineRenderer
    }
    
    // annotation이 만들어 질 때 생성
    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        } else {
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "reuseId") ?? MKAnnotationView()
            annotationView.canShowCallout = true
            
            // 직접 extension해서 추가한 resize함수
            let width = self.view.frame.width / 7
            let height = self.view.frame.height / 7
            let img = UIImage.resize(image: self.imageIcon!, targetSize: CGSize(width: width, height: height))
            
            annotationView.image = img
            
            return annotationView
        }
    }
}

// MARK: - location delegate
extension MapViewController: CLLocationManagerDelegate {
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latitude = locations[0].coordinate.latitude
        let longitude = locations[0].coordinate.longitude
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = formatter.string(from: Date())
        
        self.draw(latitude: latitude, longitude: longitude, date: date)
    }
    
    open func draw(latitude: Double, longitude: Double, date: String) {
        
        let latitudeTmp = latitude
        let longitudeTmp = longitude
        let curDate = date
        
        let totalData = Location()
        totalData.date = getSequenceDate(strValue: curDate)
        totalData.latitude = latitudeTmp
        totalData.longitude = longitudeTmp
        
        myLocationsInfo.append(totalData)
        
        let spanX = 0.005
        let spanY = 0.005
        
        let newRegion = MKCoordinateRegion(center: mapView.userLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: spanX, longitudeDelta: spanY))
        
        mapView.setRegion(newRegion, animated: true)
        
        // 중지 상태이면 맵에 흔적을 표시하지 않음
        if(self.isStopDraw == true) {            
            self.myLocationsInfo.removeAll()
            return
        }
        
        if (myLocationsInfo.count > 3) {
            let sourceIndex = myLocationsInfo.count - 1
            let destinationIndex = myLocationsInfo.count - 2
            
            let c1 = myLocationsInfo[sourceIndex].latitude
            let c2 = myLocationsInfo[sourceIndex].longitude
            
            let c3 = myLocationsInfo[destinationIndex].latitude
            let c4 = myLocationsInfo[destinationIndex].longitude
            
            let source = CLLocationCoordinate2D(latitude: c1, longitude: c2)
            let destination = CLLocationCoordinate2D(latitude: c3, longitude: c4)
            
            var coordinateInfomation = [source, destination]
            let polyline = MKPolyline(coordinates: &coordinateInfomation, count: coordinateInfomation.count)
            mapView.addOverlay(polyline)
        }
    }
    
    func getSequenceDate(strValue: String) -> Double {
        let valueArr = strValue.components(separatedBy: " ")
        let valueFirstArr = valueArr[0].components(separatedBy: "-")
        let valueSecondArr = valueArr[1].components(separatedBy: ":")
        var valueStr = ""
        
        for i in 0..<3 {
            valueStr += valueFirstArr[i]
        }
        
        for i in 0..<3 {
            valueStr += valueSecondArr[i]
        }
        
        return NumberFormatter().number(from: valueStr)!.doubleValue
    }
    
}

// MARK: - resize image
extension UIImage {
    class func resize(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / image.size.width
        let heightRatio = targetSize.height / image.size.height
        
        var newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    class func scale(image: UIImage, by scale: CGFloat) -> UIImage? {
        let size = image.size
        let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIImage.resize(image: image, targetSize: scaledSize)
    }
}

// MARK: - image picker
extension MapViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
       
    public func selectImg() {
        
        let msg = "Select the image"
        let sheet = UIAlertController(title: nil, message: msg, preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        let savedAlbum = UIAlertAction(title: "Saved Album", style: .default) { (_) in
            self.selectLibrary(src: .savedPhotosAlbum)
        }
        
        let photoLibrary = UIAlertAction(title: "Photo Library", style: .default){(_) in
            self.selectLibrary(src: .photoLibrary)
        }
        
        let camera = UIAlertAction(title: "Camera", style: .default){(_) in
            self.selectLibrary(src: .camera)
        }
        
        sheet.addAction(savedAlbum)
        sheet.addAction(photoLibrary)
        sheet.addAction(camera)
        
        self.present(sheet, animated: false)
    }
    
    private func selectLibrary(src: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        
        self.present(picker, animated: false)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let img = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            self.imageIcon = img
        }
        
        self.dismiss(animated: true)
    }
}
