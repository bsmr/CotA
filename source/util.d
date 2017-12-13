module util;

private
{
  import gdk.RGBA;
  import glib.Internationalization;
  import gtk.Widget;
  import std.algorithm.comparison;
  import std.conv;
  import std.datetime;
  import std.string;
}

/**
 * Localize a string.
 */
string t(string text)
{
  return Internationalization.dgettext([], text);
}

/**
 * Sets the left, top, right and bottom margins for a widget.
 */
void setMargins(Widget widget, int left, int top, int right, int bottom)
{
  widget.setMarginLeft(left);
  widget.setMarginTop(top);
  widget.setMarginRight(right);
  widget.setMarginBottom(bottom);
}

/**
 * Converts an RGBA color to text in HTML notation.
 */
string htmlColor(RGBA color, double opacity = 1.0)
{
  return format!("#%02x%02x%02x%02x")(cast(int)(color.red * 255 + 0.5),
      cast(int)(color.green * 255 + 0.5), cast(int)(color.blue * 255 + 0.5),
      cast(int)(color.alpha * clamp(opacity, 0.0, 1.0) * 255 + 0.5));
}

/**
 * Convert a SotA logfile date string into a sortable format.
 */
string dateSortable(string date)
{
  // Split the string into the date, time and am/pm components.
  immutable auto components = date.split();
  if (components.length != 3)
    return [];

  // Split the date component into the year, month and day parts.
  immutable auto dateParts = components[0].split("/");
  if (dateParts.length != 3)
    return [];

  // Convert the year, month and day to integers.
  immutable auto month = to!(int)(dateParts[0]);
  immutable auto day = to!(int)(dateParts[1]);
  immutable auto year = to!(int)(dateParts[2]);

  // Split the time component into the hour, minute and second parts.
  immutable auto timeParts = components[1].split(":");
  if (timeParts.length != 3)
    return [];

  // Convert the hour, minute and second to integers and convert to 24 hour
  // format.
  immutable auto hour = to!(int)(timeParts[0]) + (icmp(components[2], "PM") == 0 ? 12 : 0);
  immutable auto minute = to!(int)(timeParts[1]);
  immutable auto second = to!(int)(timeParts[2]);

  // Recombine the elements into a sortable string.
  return format!("%04d%02d%02d%02d%02d%02d")(year, month, day, hour, minute, second);
}

/**
 * Returns the current lunar phase as a double.
 */
double getLunarPhase()
{
  // Get the current UTC time.
  auto dateTime = cast(DateTime) Clock.currTime(UTC());

  // Get the duration since the lunar rift epoch.
  immutable auto duration = dateTime - DateTime(1997, 9, 2, 0, 0, 0);

  // Calculate the lunar phase from the duration. Each phase is 525 seconds and
  // there are 8 phases, for a total of 4200 seconds per lunar cycle.
  return (duration.total!("seconds") % 4200) / 525.0;
}
