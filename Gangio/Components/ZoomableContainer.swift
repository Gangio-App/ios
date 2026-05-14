//
//  ZoomableContainer.swift
//  Gangio
//
//  Discord/Photos-style zoom container backed by a UIScrollView so pinch and
//  pan feel native. Supports double-tap-to-toggle (1x ↔ 2.5x).
//

import SwiftUI
import UIKit

struct ZoomableContainer<Content: View>: UIViewRepresentable {
    let maxScale: CGFloat
    let minScale: CGFloat
    let doubleTapScale: CGFloat
    let content: Content
    
    init(
        maxScale: CGFloat = 5.0,
        minScale: CGFloat = 1.0,
        doubleTapScale: CGFloat = 2.5,
        @ViewBuilder content: () -> Content
    ) {
        self.maxScale = maxScale
        self.minScale = minScale
        self.doubleTapScale = doubleTapScale
        self.content = content()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.maximumZoomScale = maxScale
        scroll.minimumZoomScale = minScale
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.backgroundColor = .clear
        
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(host.view)
        context.coordinator.hostingController = host
        
        // Pin hosted view to scroll's contentLayoutGuide so it scales correctly.
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            host.view.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
        
        // Double-tap: toggle zoom level
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        context.coordinator.scrollView = scroll
        context.coordinator.doubleTapScale = doubleTapScale
        
        return scroll
    }
    
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content
    }
    
    final class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>?
        weak var scrollView: UIScrollView?
        var doubleTapScale: CGFloat = 2.5
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController?.view
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scroll = scrollView else { return }
            if scroll.zoomScale > scroll.minimumZoomScale + 0.01 {
                scroll.setZoomScale(scroll.minimumZoomScale, animated: true)
            } else {
                let location = gesture.location(in: hostingController?.view)
                let size = scroll.bounds.size
                let w = size.width / doubleTapScale
                let h = size.height / doubleTapScale
                let rect = CGRect(x: location.x - w / 2, y: location.y - h / 2, width: w, height: h)
                scroll.zoom(to: rect, animated: true)
            }
        }
    }
}
