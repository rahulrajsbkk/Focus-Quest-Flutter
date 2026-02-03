package me.rahulrajsb.focus

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File

class FocusQuestWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val imagePath = widgetData.getString("activity_heatmap_image", null)
                if (imagePath != null) {
                     val file = File(imagePath)
                     if (file.exists()) {
                         val bitmap = BitmapFactory.decodeFile(imagePath)
                         setImageViewBitmap(R.id.activity_heatmap_image, bitmap)
                     }
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
