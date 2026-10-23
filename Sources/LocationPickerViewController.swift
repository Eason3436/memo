import UIKit
import MapKit

/// 選擇地點：搜尋、長按地圖標記，或使用目前位置
final class LocationPickerViewController: UIViewController {

    /// 選好地點時呼叫；傳 nil 代表移除地點
    var onPick: ((NoteLocation?) -> Void)?

    private let initial: NoteLocation?
    private let mapView = MKMapView()
    private let searchController = UISearchController(searchResultsController: nil)
    private let locationManager = CLLocationManager()
    private var wantsCurrentLocation = false

    init(initial: NoteLocation?) {
        self.initial = initial
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "地點"
        view.backgroundColor = .systemBackground

        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        view.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        if initial != nil {
            let remove = UIBarButtonItem(title: "移除", primaryAction: UIAction { [weak self] _ in
                self?.finish(nil)
            })
            remove.tintColor = .systemRed
            navigationItem.rightBarButtonItem = remove
        }

        // 搜尋列
        searchController.searchBar.placeholder = "搜尋地點或地址"
        searchController.searchBar.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        // 底部工具列：定位 + 使用目前位置
        let current = UIBarButtonItem(primaryAction: UIAction(title: "使用目前位置",
                                                              image: UIImage(systemName: "location.fill")) { [weak self] _ in
            self?.useCurrentLocation()
        })
        toolbarItems = [MKUserTrackingBarButtonItem(mapView: mapView), .flexibleSpace(), current]

        // 長按地圖放標記
        mapView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(dropPin(_:))))

        locationManager.delegate = self
        if isLocationAuthorized { mapView.showsUserLocation = true }

        if let initial {
            mapView.setRegion(MKCoordinateRegion(center: initial.coordinate,
                                                 latitudinalMeters: 1000, longitudinalMeters: 1000), animated: false)
            show([initial])
        }
    }

    private var isLocationAuthorized: Bool {
        [.authorizedWhenInUse, .authorizedAlways].contains(locationManager.authorizationStatus)
    }

    private func finish(_ location: NoteLocation?) {
        onPick?(location)
        dismiss(animated: true)
    }

    /// 在地圖上顯示候選地點，只有一個時直接打開說明框
    private func show(_ locations: [NoteLocation]) {
        mapView.removeAnnotations(mapView.annotations.filter { $0 is PlaceAnnotation })
        let annotations = locations.map(PlaceAnnotation.init)
        mapView.showAnnotations(annotations, animated: true)
        if annotations.count == 1 { mapView.selectAnnotation(annotations[0], animated: true) }
    }

    /// 用座標反查地名
    private func placeLocation(at location: CLLocation, fallbackName: String) async -> NoteLocation {
        var result = NoteLocation(name: fallbackName, address: nil,
                                  latitude: location.coordinate.latitude,
                                  longitude: location.coordinate.longitude)
        if let request = MKReverseGeocodingRequest(location: location),
           let item = try? await request.mapItems.first {
            result.name = item.name ?? fallbackName
            result.address = item.address?.shortAddress
        }
        return result
    }

    @objc private func dropPin(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let coordinate = mapView.convert(gesture.location(in: mapView), toCoordinateFrom: mapView)
        Task {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            show([await placeLocation(at: location, fallbackName: "標記的位置")])
        }
    }

    private func useCurrentLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            wantsCurrentLocation = true
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showAlert("無法取得位置", "請到「設定」允許「MemoApp」使用位置。")
        default:
            wantsCurrentLocation = true
            locationManager.requestLocation()
        }
    }
}

// MARK: - 搜尋

extension LocationPickerViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text, !query.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = mapView.region
        Task {
            do {
                let response = try await MKLocalSearch(request: request).start()
                searchController.isActive = false
                show(response.mapItems.map(NoteLocation.init(mapItem:)))
            } catch {
                showAlert("找不到地點", "換個關鍵字試試看。")
            }
        }
    }
}

// MARK: - 地圖

extension LocationPickerViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is PlaceAnnotation else { return nil }
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: "place") as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "place")
        view.annotation = annotation
        view.canShowCallout = true
        view.markerTintColor = .systemOrange
        let choose = UIButton(type: .system)
        choose.setTitle("選擇", for: .normal)
        choose.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        choose.sizeToFit()
        view.rightCalloutAccessoryView = choose
        return view
    }

    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
                 calloutAccessoryControlTapped control: UIControl) {
        guard let place = view.annotation as? PlaceAnnotation else { return }
        finish(place.location)
    }
}

// MARK: - 定位

extension LocationPickerViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isLocationAuthorized else { return }
        mapView.showsUserLocation = true
        if wantsCurrentLocation { manager.requestLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard wantsCurrentLocation, let location = locations.last else { return }
        wantsCurrentLocation = false
        Task { finish(await placeLocation(at: location, fallbackName: "目前位置")) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard wantsCurrentLocation else { return }
        wantsCurrentLocation = false
        showAlert("無法取得位置", error.localizedDescription)
    }
}

/// 地圖上的候選地點
private final class PlaceAnnotation: NSObject, MKAnnotation {
    let location: NoteLocation
    var coordinate: CLLocationCoordinate2D { location.coordinate }
    var title: String? { location.name }
    var subtitle: String? { location.address }

    init(location: NoteLocation) {
        self.location = location
    }
}

extension NoteLocation {
    init(mapItem: MKMapItem) {
        self.init(name: mapItem.name ?? "地點",
                  address: mapItem.address?.shortAddress,
                  latitude: mapItem.location.coordinate.latitude,
                  longitude: mapItem.location.coordinate.longitude)
    }

    /// 在 Apple「地圖」App 打開
    func openInMaps() {
        let item = MKMapItem(location: CLLocation(latitude: latitude, longitude: longitude), address: nil)
        item.name = name
        item.openInMaps()
    }
}
