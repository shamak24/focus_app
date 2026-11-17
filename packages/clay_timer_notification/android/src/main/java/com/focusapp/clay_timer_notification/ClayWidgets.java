package com.focusapp.clay_timer_notification;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.view.View;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Calendar;

/**
 * Draws the home-screen widgets from the last snapshot the app sent.
 *
 * <p>The app pushes a snapshot (timer, next tasks, colours) whenever any of it
 * changes; it is kept in SharedPreferences so the widgets can redraw after a
 * reboot or launcher restart without the app running. Two things happen with
 * no app at all, so they are handled here: a running timer reaching its end
 * (the widget drops back to "Start focus"), and midnight (daily tasks done
 * yesterday come back).
 */
final class ClayWidgets {
  private ClayWidgets() {}

  static final String ACTION_REFRESH = "com.focusapp.clay.WIDGET_REFRESH";
  private static final String PREFS = "clay_widgets";
  private static final String KEY_SNAPSHOT = "snapshot";
  private static final int MAX_TASK_ROWS = 3;

  private static final int[] ROWS = {R.id.clay_task0, R.id.clay_task1, R.id.clay_task2};
  private static final int[] ROW_DOTS = {R.id.clay_task0_dot, R.id.clay_task1_dot, R.id.clay_task2_dot};
  private static final int[] ROW_TITLES = {R.id.clay_task0_title, R.id.clay_task1_title, R.id.clay_task2_title};
  private static final int[] ROW_SUBS = {R.id.clay_task0_sub, R.id.clay_task1_sub, R.id.clay_task2_sub};
  private static final int[] ROW_PLAYS = {R.id.clay_task0_play, R.id.clay_task1_play, R.id.clay_task2_play};
  private static final int[] ROW_PLAY_BGS = {R.id.clay_task0_play_bg, R.id.clay_task1_play_bg, R.id.clay_task2_play_bg};
  private static final int[] ROW_PLAY_ICONS = {R.id.clay_task0_play_icon, R.id.clay_task1_play_icon, R.id.clay_task2_play_icon};

  static void store(Context ctx, JSONObject snapshot) {
    prefs(ctx).edit().putString(KEY_SNAPSHOT, snapshot.toString()).apply();
    renderAll(ctx);
  }

  /** Redraws every placed widget and re-arms the refresh alarms. */
  static void renderAll(Context ctx) {
    final AppWidgetManager manager = AppWidgetManager.getInstance(ctx);
    final int[] small = manager.getAppWidgetIds(new ComponentName(ctx, ClayTimerWidgetSmall.class));
    final int[] medium = manager.getAppWidgetIds(new ComponentName(ctx, ClayTimerWidgetMedium.class));
    final JSONObject snap = load(ctx);
    final State state = new State(snap);
    if (small.length > 0) manager.updateAppWidget(small, build(ctx, state, false));
    if (medium.length > 0) manager.updateAppWidget(medium, build(ctx, state, true));
    scheduleRefreshes(ctx, state, small.length + medium.length > 0);
  }

  /** The snapshot, read once per redraw, with expired timers already dropped. */
  private static final class State {
    final ClayDraw.Palette palette;
    final JSONObject snap;
    final JSONObject timer;
    final boolean running;
    final long endsAt;
    final int pausedSeconds;
    final JSONArray tasks;

    State(JSONObject snap) {
      this.snap = snap;
      palette = new ClayDraw.Palette(snap.optJSONObject("colors") == null ? new JSONObject() : snap.optJSONObject("colors"));
      JSONObject t = snap.optJSONObject("timer");
      final long now = System.currentTimeMillis();
      boolean run = t != null && t.isNull("pausedRemainingSeconds");
      final long end = t == null ? 0 : t.optLong("endsAtMillis", 0);
      // A timer that has run out while nobody was watching is over.
      if (run && end <= now) {
        t = null;
        run = false;
      }
      timer = t;
      running = run;
      endsAt = end;
      pausedSeconds = t == null || t.isNull("pausedRemainingSeconds") ? 0 : t.optInt("pausedRemainingSeconds");
      tasks = openToday(snap.optJSONArray("tasks"));
    }
  }

  private static RemoteViews build(Context ctx, State s, boolean medium) {
    final ClayDraw.Palette p = s.palette;
    final RemoteViews v =
        new RemoteViews(ctx.getPackageName(), medium ? R.layout.clay_widget_medium : R.layout.clay_widget_small);
    ClayDraw.paintCard(v, p);

    // Tapping the card opens the timer if one is running, otherwise the
    // task picker: the app's "Start focus" does exactly that.
    final PendingIntent focus = ClayDraw.openAppIntent(ctx, "focus");
    v.setOnClickPendingIntent(R.id.clay_root, focus);

    if (s.timer != null) {
      v.setViewVisibility(R.id.clay_running, View.VISIBLE);
      v.setViewVisibility(R.id.clay_idle, View.GONE);
      v.setTextViewText(R.id.clay_title, s.timer.optString("title"));
      v.setTextColor(R.id.clay_title, p.ink);
      ClayDraw.paintPill(v, p);
      ClayDraw.setCountdown(v, s.running, s.endsAt, s.pausedSeconds, p.ink);
      v.setOnClickPendingIntent(R.id.clay_countdown, focus);

      final String toggleId = s.snap.optString(s.running ? "pauseId" : "resumeId");
      ClayDraw.setButton(
          ctx, v, R.id.clay_toggle, R.id.clay_toggle_bg, R.id.clay_toggle_icon, 44,
          p.primary, s.running ? R.drawable.ic_clay_pause : R.drawable.ic_clay_play, p.onPrimary, p,
          ClayDraw.actionIntent(ctx, 0, toggleId, false),
          ctx.getString(s.running ? R.string.clay_pause : R.string.clay_resume));
      ClayDraw.setButton(
          ctx, v, R.id.clay_stop, R.id.clay_stop_bg, R.id.clay_stop_icon, 44,
          p.surface, R.drawable.ic_clay_stop, p.ink, p,
          ClayDraw.actionIntent(ctx, 0, s.snap.optString("stopId"), false),
          ctx.getString(R.string.clay_stop));
    } else {
      v.setViewVisibility(R.id.clay_running, View.GONE);
      v.setViewVisibility(R.id.clay_idle, View.VISIBLE);
      ClayDraw.setButton(
          ctx, v, R.id.clay_start, R.id.clay_start_bg, R.id.clay_start_icon, 64,
          p.primary, R.drawable.ic_clay_play, p.onPrimary, p, focus,
          ctx.getString(R.string.clay_start_focus));
      v.setTextColor(R.id.clay_idle_label, p.ink);
      final JSONObject next = s.tasks.optJSONObject(0);
      v.setTextViewText(
          R.id.clay_idle_sub,
          next == null
              ? ctx.getString(R.string.clay_pick_a_task)
              : ctx.getString(R.string.clay_next_task, next.optString("title")));
      v.setTextColor(R.id.clay_idle_sub, ClayDraw.withAlpha(p.ink, 0.62f));
    }

    if (medium) fillTaskRows(ctx, v, s);
    return v;
  }

  /** The "Up next" column: up to three tasks, each with a start button. */
  private static void fillTaskRows(Context ctx, RemoteViews v, State s) {
    final ClayDraw.Palette p = s.palette;
    v.setTextColor(R.id.clay_upnext_label, ClayDraw.withAlpha(p.ink, 0.62f));
    final String startPrefix = s.snap.optString("startPrefix");
    final int count = Math.min(MAX_TASK_ROWS, s.tasks.length());
    for (int i = 0; i < MAX_TASK_ROWS; i++) {
      if (i >= count) {
        v.setViewVisibility(ROWS[i], View.INVISIBLE);
        continue;
      }
      final JSONObject task = s.tasks.optJSONObject(i);
      v.setViewVisibility(ROWS[i], View.VISIBLE);
      v.setTextViewText(ROW_TITLES[i], task.optString("title"));
      v.setTextColor(ROW_TITLES[i], p.ink);
      v.setTextViewText(ROW_SUBS[i], task.optString("subtitle"));
      v.setTextColor(ROW_SUBS[i], ClayDraw.withAlpha(p.ink, 0.62f));
      final int color = task.optInt("color", 0);
      v.setInt(ROW_DOTS[i], "setColorFilter", ClayDraw.opaque(color == 0 ? p.primary : color));
      ClayDraw.setButton(
          ctx, v, ROW_PLAYS[i], ROW_PLAY_BGS[i], ROW_PLAY_ICONS[i], 30,
          p.surface, R.drawable.ic_clay_play, p.ink, p,
          ClayDraw.actionIntent(ctx, 0, startPrefix + task.optString("id"), false),
          ctx.getString(R.string.clay_start_task, task.optString("title")));
    }
    v.setViewVisibility(R.id.clay_tasks_empty, count == 0 ? View.VISIBLE : View.GONE);
    v.setTextColor(R.id.clay_tasks_empty, ClayDraw.withAlpha(p.ink, 0.62f));
  }

  /**
   * Tasks not done today. Daily tasks finished today arrive marked with
   * today's date, so after midnight they show again without the app.
   */
  private static JSONArray openToday(JSONArray all) {
    final JSONArray out = new JSONArray();
    if (all == null) return out;
    final int today = dayKey(Calendar.getInstance());
    for (int i = 0; i < all.length(); i++) {
      final JSONObject task = all.optJSONObject(i);
      if (task == null) continue;
      if (!task.isNull("doneDay") && task.optInt("doneDay") == today) continue;
      out.put(task);
    }
    return out;
  }

  /** yyyymmdd in local time, matching what the app sends. */
  private static int dayKey(Calendar c) {
    return c.get(Calendar.YEAR) * 10000 + (c.get(Calendar.MONTH) + 1) * 100 + c.get(Calendar.DAY_OF_MONTH);
  }

  private static void scheduleRefreshes(Context ctx, State s, boolean anyWidgets) {
    final AlarmManager alarms = ctx.getSystemService(AlarmManager.class);
    if (alarms == null) return;
    final PendingIntent atEnd = refreshIntent(ctx, 1);
    final PendingIntent atMidnight = refreshIntent(ctx, 2);
    if (!anyWidgets) {
      alarms.cancel(atEnd);
      alarms.cancel(atMidnight);
      return;
    }

    if (s.running) {
      final long when = s.endsAt + 1000;
      try {
        if (Build.VERSION.SDK_INT >= 31 && !alarms.canScheduleExactAlarms()) {
          alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, when, atEnd);
        } else {
          alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, when, atEnd);
        }
      } catch (SecurityException e) {
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, when, atEnd);
      }
    } else {
      alarms.cancel(atEnd);
    }

    // No need to wake the phone for this: it is redrawn whenever it next wakes.
    final Calendar midnight = Calendar.getInstance();
    midnight.add(Calendar.DAY_OF_MONTH, 1);
    midnight.set(Calendar.HOUR_OF_DAY, 0);
    midnight.set(Calendar.MINUTE, 0);
    midnight.set(Calendar.SECOND, 30);
    midnight.set(Calendar.MILLISECOND, 0);
    alarms.set(AlarmManager.RTC, midnight.getTimeInMillis(), atMidnight);
  }

  private static PendingIntent refreshIntent(Context ctx, int requestCode) {
    final Intent intent = new Intent(ctx, ClayTimerWidgetSmall.class).setAction(ACTION_REFRESH);
    return PendingIntent.getBroadcast(
        ctx, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
  }

  private static JSONObject load(Context ctx) {
    try {
      return new JSONObject(prefs(ctx).getString(KEY_SNAPSHOT, "{}"));
    } catch (Exception e) {
      return new JSONObject();
    }
  }

  private static SharedPreferences prefs(Context ctx) {
    return ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
  }
}
