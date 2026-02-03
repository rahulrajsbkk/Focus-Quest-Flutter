//
//  HeatmapWidgetBundle.swift
//  HeatmapWidget
//
//  Created by Rahul on 03/02/26.
//

import WidgetKit
import SwiftUI

@main
struct HeatmapWidgetBundle: WidgetBundle {
    var body: some Widget {
        HeatmapWidget()
        HeatmapWidgetControl()
        HeatmapWidgetLiveActivity()
    }
}
