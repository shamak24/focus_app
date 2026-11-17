package com.focusapp.clay_timer_notification;

import android.app.Activity;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.widget.RemoteViews;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import org.json.JSONObject;

import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * The app's clay-styled Android surfaces: the running-timer notification and
 * the home-screen widgets.
 *
 * <p>Registered as a plugin (not in MainActivity) so it is also available in
 * the background engine that flutter_local_notifications starts for button
 * taps while the app is closed.
 */
public class ClayTimerNotificationPlugin
    implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
        PluginRegistry.NewIntentListener {

  private MethodChannel channel;
  private Context context;
  private ActivityPluginBinding activityBinding;

  /** What a widget asked the app to show when it opened it, until Dart takes it. */
  private String pendingLaunchAction;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    context = binding.getApplicationContext();
    channel = new MethodChannel(binding.getBinaryMessenger(), "clay_timer_notification");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    channel = null;
  }

  // Launch actions: a widget opens the app with an extra saying what to show.

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activityBinding = binding;
    binding.addOnNewIntentListener(this);
    pendingLaunchAction = takeLaunchAction(binding.getActivity().getIntent());
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    activityBinding = binding;
    binding.addOnNewIntentListener(this);
  }

  @Override
  public void onDetachedFromActivity() {
    if (activityBinding != null) activityBinding.removeOnNewIntentListener(this);
    activityBinding = null;
  }

  @Override
  public boolean onNewIntent(@NonNull Intent intent) {
    final String action = takeLaunchAction(intent);
    if (action != null && channel != null) channel.invokeMethod("launchAction", action);
    return false;
  }

  /** Reads and removes the extra, so a rotation or restore does not repeat it. */
  private static String takeLaunchAction(Intent intent) {
    if (intent == null) return null;
    final String action = intent.getStringExtra(ClayDraw.EXTRA_LAUNCH_ACTION);
    intent.removeExtra(ClayDraw.EXTRA_LAUNCH_ACTION);
    return action;
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    try {
      switch (call.method) {
        case "show":
          show(call);
          result.success(null);
          break;
        case "cancel":
          Integer id = call.argument("id");
          NotificationManagerCompat.from(context).cancel(id == null ? 0 : id);
          result.success(null);
          break;
        case "updateWidgets":
          final Map<String, Object> snapshot = call.argument("snapshot");
          ClayWidgets.store(context, new JSONObject(snapshot));
          result.success(null);
          break;
        case "takeLaunchAction":
          result.success(pendingLaunchAction);
          pendingLaunchAction = null;
          break;
        default:
          result.notImplemented();
      }
    } catch (SecurityException e) {
      // Notification permission not granted: nothing to show.
      result.success(null);
    } catch (Exception e) {
      result.error("clay_surface_failed", e.getMessage(), null);
    }
  }

  private void show(MethodCall call) {
    final int id = call.argument("id");
    final String channelId = call.argument("channelId");
    final String title = call.argument("title");
    final String status = call.argument("status");
    final long endsAt = ((Number) call.argument("endsAtMillis")).longValue();
    final Integer paused = call.argument("pausedRemainingSeconds");
    final Map<String, Object> colors = call.argument("colors");
    final ClayDraw.Palette p = new ClayDraw.Palette(new JSONObject(colors));

    ensureChannel(channelId, call.argument("channelName"), call.argument("channelDescription"));

    final long remainingMs = endsAt - System.currentTimeMillis();
    final boolean running = paused == null;
    if (running && remainingMs <= 0) {
      NotificationManagerCompat.from(context).cancel(id);
      return;
    }

    final String toggleId = call.argument(running ? "pauseId" : "resumeId");
    final String toggleLabel = call.argument(running ? "pauseLabel" : "resumeLabel");
    final String stopId = call.argument("stopId");
    final String stopLabel = call.argument("stopLabel");

    final PendingIntent toggle = ClayDraw.actionIntent(context, id, toggleId, false);
    final PendingIntent stop = ClayDraw.actionIntent(context, id, stopId, true);
    final PendingIntent open = ClayDraw.openAppIntent(context, null);

    final RemoteViews collapsed = new RemoteViews(context.getPackageName(), R.layout.clay_timer_collapsed);
    final RemoteViews expanded = new RemoteViews(context.getPackageName(), R.layout.clay_timer_expanded);
    for (RemoteViews v : new RemoteViews[] {collapsed, expanded}) {
      final boolean big = v == expanded;
      ClayDraw.paintCard(v, p);
      // Taps anywhere but the two buttons just open the app. Set explicitly
      // rather than left to the notification's content intent, so a tap on
      // the countdown can never be taken as a button press.
      if (open != null) {
        v.setOnClickPendingIntent(R.id.clay_content, open);
        v.setOnClickPendingIntent(R.id.clay_countdown, open);
        v.setOnClickPendingIntent(R.id.clay_title, open);
      }
      v.setTextViewText(R.id.clay_title, title);
      v.setTextColor(R.id.clay_title, p.ink);
      if (big) {
        v.setTextViewText(R.id.clay_status, status);
        v.setTextColor(R.id.clay_status, ClayDraw.withAlpha(p.ink, 0.62f));
        ClayDraw.paintPill(v, p);
      }
      ClayDraw.setCountdown(v, running, endsAt, paused == null ? 0 : paused, p.ink);

      final int size = big ? 56 : 36;
      ClayDraw.setButton(
          context, v, R.id.clay_toggle, R.id.clay_toggle_bg, R.id.clay_toggle_icon, size,
          p.primary, running ? R.drawable.ic_clay_pause : R.drawable.ic_clay_play, p.onPrimary,
          p, toggle, toggleLabel);
      ClayDraw.setButton(
          context, v, R.id.clay_stop, R.id.clay_stop_bg, R.id.clay_stop_icon, size,
          p.surface, R.drawable.ic_clay_stop, p.ink, p, stop, stopLabel);
    }

    final NotificationCompat.Builder builder =
        new NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_stat_focus)
            .setColor(ClayDraw.opaque(p.primary))
            .setContentTitle(title)
            .setContentText(status)
            .setStyle(new NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(collapsed)
            .setCustomBigContentView(expanded)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(open);
    // Removes itself at the end in case the app is not running to do it.
    if (running) builder.setTimeoutAfter(remainingMs);

    NotificationManagerCompat.from(context).notify(id, builder.build());
  }

  private void ensureChannel(String id, String name, String description) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
    final NotificationChannel ch =
        new NotificationChannel(id, name, NotificationManager.IMPORTANCE_LOW);
    ch.setDescription(description);
    ch.setShowBadge(false);
    ch.setSound(null, null);
    ch.enableVibration(false);
    context.getSystemService(NotificationManager.class).createNotificationChannel(ch);
  }
}
