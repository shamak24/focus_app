package com.focusapp.clay_timer_notification;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

/** Shared behaviour of both widget sizes: everything redraws from the snapshot. */
abstract class ClayWidgetProvider extends AppWidgetProvider {
  @Override
  public void onReceive(Context context, Intent intent) {
    super.onReceive(context, intent);
    if (ClayWidgets.ACTION_REFRESH.equals(intent.getAction())) ClayWidgets.renderAll(context);
  }

  @Override
  public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
    ClayWidgets.renderAll(context);
  }

  @Override
  public void onAppWidgetOptionsChanged(Context context, AppWidgetManager manager, int id, Bundle options) {
    ClayWidgets.renderAll(context);
  }

  @Override
  public void onDisabled(Context context) {
    // The last widget of this size was removed: re-arm or cancel alarms.
    ClayWidgets.renderAll(context);
  }
}
