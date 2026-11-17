package com.focusapp.clay_timer_notification;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BlurMaskFilter;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.RadialGradient;
import android.graphics.Shader;
import android.os.SystemClock;
import android.view.View;
import android.widget.RemoteViews;

import org.json.JSONObject;

import java.util.Locale;

/**
 * Clay drawing shared by the notification and the home-screen widgets: the
 * layered card, round raised buttons, the countdown, and the intents behind
 * taps.
 */
final class ClayDraw {
  private ClayDraw() {}

  // Button taps go to flutter_local_notifications' receiver, which hands them
  // to the app's background notification-response callback. That works
  // whether or not the app is running.
  private static final String ACTION_RECEIVER =
      "com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver";
  private static final String ACTION_TAPPED = ACTION_RECEIVER + ".ACTION_TAPPED";

  /** Extra on the launch intent telling the app what to show when it opens. */
  static final String EXTRA_LAUNCH_ACTION = "com.focusapp.clay.LAUNCH_ACTION";

  /** Theme colours sent from Dart as ARGB ints. */
  static final class Palette {
    final int background, surface, primary, onPrimary, ink, shadow, highlight;

    Palette(JSONObject m) {
      background = m.optInt("background", 0xFFFFEEE2);
      surface = m.optInt("surface", 0xFFFFF8F2);
      primary = m.optInt("primary", 0xFFFF8A65);
      onPrimary = m.optInt("onPrimary", 0xFF4A2317);
      ink = m.optInt("ink", 0xFF4A342B);
      shadow = m.optInt("shadow", 0x66C99774);
      highlight = m.optInt("highlight", 0xE6FFFFFF);
    }
  }

  /** Tints the stacked card layers: two soft shadows, the fill, then the sheen. */
  static void paintCard(RemoteViews v, Palette p) {
    final int shadowAlpha = Color.alpha(p.shadow);
    v.setInt(R.id.clay_shadow_far, "setColorFilter", opaque(p.shadow));
    v.setInt(R.id.clay_shadow_far, "setImageAlpha", Math.round(shadowAlpha * 0.45f));
    v.setInt(R.id.clay_shadow_near, "setColorFilter", opaque(p.shadow));
    v.setInt(R.id.clay_shadow_near, "setImageAlpha", Math.round(shadowAlpha * 0.8f));
    v.setInt(R.id.clay_fill, "setColorFilter", opaque(p.surface));
    v.setInt(R.id.clay_sheen, "setColorFilter", opaque(p.highlight));
    v.setInt(R.id.clay_sheen, "setImageAlpha", Color.alpha(p.highlight));
  }

  /** Tints a pill pressed into the card (ids clay_pill / clay_pill_inset). */
  static void paintPill(RemoteViews v, Palette p) {
    v.setInt(R.id.clay_pill, "setColorFilter", opaque(p.background));
    v.setInt(R.id.clay_pill_inset, "setColorFilter", opaque(p.shadow));
    v.setInt(R.id.clay_pill_inset, "setImageAlpha", Math.round(Color.alpha(p.shadow) * 0.9f));
  }

  /**
   * Live countdown to [endsAt] while running (the system ticks it), or the
   * frozen time left while paused. Uses ids clay_chrono / clay_paused_time.
   */
  static void setCountdown(RemoteViews v, boolean running, long endsAt, int pausedSeconds, int ink) {
    if (running) {
      final long base = SystemClock.elapsedRealtime() + (endsAt - System.currentTimeMillis());
      v.setChronometer(R.id.clay_chrono, base, null, true);
      v.setChronometerCountDown(R.id.clay_chrono, true);
      v.setTextColor(R.id.clay_chrono, ink);
      v.setViewVisibility(R.id.clay_chrono, View.VISIBLE);
      v.setViewVisibility(R.id.clay_paused_time, View.GONE);
    } else {
      v.setChronometer(R.id.clay_chrono, SystemClock.elapsedRealtime(), null, false);
      v.setTextViewText(R.id.clay_paused_time, mmss(pausedSeconds));
      v.setTextColor(R.id.clay_paused_time, withAlpha(ink, 0.7f));
      v.setViewVisibility(R.id.clay_paused_time, View.VISIBLE);
      v.setViewVisibility(R.id.clay_chrono, View.GONE);
    }
  }

  /**
   * Fills a round clay button made of a frame [frameId] holding a background
   * image [bgId] and an icon [iconId].
   */
  static void setButton(
      Context ctx, RemoteViews v, int frameId, int bgId, int iconId,
      int sizeDp, int fill, int iconRes, int iconColor, Palette p,
      PendingIntent onTap, String label) {
    v.setImageViewBitmap(bgId, clayButton(ctx, sizeDp, fill, p.shadow, p.highlight));
    v.setImageViewResource(iconId, iconRes);
    v.setInt(iconId, "setColorFilter", opaque(iconColor));
    if (onTap != null) v.setOnClickPendingIntent(frameId, onTap);
    v.setContentDescription(frameId, label);
  }

  /**
   * A round raised clay button: a blurred shadow below-right, the fill, a
   * light sheen from the top-left and a faint shade at the bottom. Drawn small
   * and scaled up, since soft shapes need no detail; the icon is a separate
   * vector on top so it stays sharp.
   */
  static Bitmap clayButton(Context ctx, int sizeDp, int fill, int shadow, int highlight) {
    final float scale = Math.min(ctx.getResources().getDisplayMetrics().density, 2f);
    final int px = Math.round(sizeDp * scale);
    final Bitmap bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888);
    final Canvas c = new Canvas(bmp);
    final float pad = px * 0.12f;
    final float r = (px - pad * 2) / 2f;
    final float cx = px / 2f - px * 0.02f;
    final float cy = px / 2f - px * 0.03f;

    final Paint shade = new Paint(Paint.ANTI_ALIAS_FLAG);
    shade.setColor(shadow);
    shade.setMaskFilter(new BlurMaskFilter(px * 0.07f, BlurMaskFilter.Blur.NORMAL));
    c.drawCircle(cx + px * 0.035f, cy + px * 0.06f, r, shade);

    final Paint base = new Paint(Paint.ANTI_ALIAS_FLAG);
    base.setColor(opaque(fill));
    c.drawCircle(cx, cy, r, base);

    final Paint sheen = new Paint(Paint.ANTI_ALIAS_FLAG);
    sheen.setShader(
        new RadialGradient(
            cx - r * 0.45f, cy - r * 0.5f, r * 1.25f,
            new int[] {withAlpha(highlight, 0.75f), withAlpha(highlight, 0f)},
            null, Shader.TileMode.CLAMP));
    c.drawCircle(cx, cy, r, sheen);

    final Paint bottom = new Paint(Paint.ANTI_ALIAS_FLAG);
    bottom.setShader(
        new LinearGradient(
            0, cy, 0, cy + r,
            new int[] {Color.TRANSPARENT, withAlpha(Color.BLACK, 0.1f)},
            null, Shader.TileMode.CLAMP));
    c.drawCircle(cx, cy, r, bottom);
    return bmp;
  }

  /**
   * A tap delivered to the app's notification-response callback with
   * [actionId]. [cancel] also removes notification [notificationId] at once.
   */
  static PendingIntent actionIntent(Context ctx, int notificationId, String actionId, boolean cancel) {
    final Intent intent =
        new Intent(ACTION_TAPPED)
            .setClassName(ctx.getPackageName(), ACTION_RECEIVER)
            .putExtra("notificationId", notificationId)
            .putExtra("actionId", actionId)
            .putExtra("cancelNotification", cancel);
    return PendingIntent.getBroadcast(
        ctx,
        (actionId + ':' + notificationId + ':' + cancel).hashCode(),
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
  }

  /**
   * Opens the app like its launcher icon does, bringing a running app to the
   * front. [launchAction] (may be null) tells it what to show.
   */
  static PendingIntent openAppIntent(Context ctx, String launchAction) {
    final Intent launch = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
    if (launch == null) return null;
    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
    if (launchAction != null) launch.putExtra(EXTRA_LAUNCH_ACTION, launchAction);
    return PendingIntent.getActivity(
        ctx,
        launchAction == null ? 0x0C1A7 : launchAction.hashCode(),
        launch,
        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
  }

  static String mmss(int seconds) {
    final int s = Math.max(0, seconds);
    if (s >= 3600) {
      return String.format(Locale.ROOT, "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60);
    }
    return String.format(Locale.ROOT, "%02d:%02d", s / 60, s % 60);
  }

  static int opaque(int color) {
    return color | 0xFF000000;
  }

  static int withAlpha(int color, float alpha) {
    return (Math.round(Color.alpha(color) * alpha) << 24) | (color & 0x00FFFFFF);
  }
}
