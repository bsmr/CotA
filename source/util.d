module util;

// dfmt off
private import gdk.RGBA;
private import std.algorithm.comparison;
private import std.conv;
private import std.datetime;
private import std.string;
// dfmt on

/// Localize a string (not implemented yet).
public string t(string text)
{
  return text;
}

/// Converts an RGBA color to text in HTML notation.
string htmlColor(RGBA color, double opacity = 1.0)
{
  return format!("#%02x%02x%02x%02x")(cast(int)(color.red() * 255),
      cast(int)(color.green() * 255), cast(int)(color.blue() * 255),
      cast(int)(color.alpha() * clamp(opacity, 0.0, 1.0) * 255));
}

/// Translate a SotA logfile date string into a sortable format.
public string dateSortable(string date)
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
  immutable auto hour = to!(int)(timeParts[0]) + (components[2].toUpper() == "PM" ? 12 : 0);
  immutable auto minute = to!(int)(timeParts[1]);
  immutable auto second = to!(int)(timeParts[2]);

  // Recombine the elements into a sortable string.
  return format!("%04d%02d%02d%02d%02d%02d")(year, month, day, hour, minute, second);
}

/// Returns the current lunar phase as a double.
double getLunarPhase()
{
  // Get the current UTC time.
  auto dateTime = cast(DateTime) Clock.currTime(UTC());

  // Calculate the number of days since Tuesday.
  int dayOffset = dateTime.dayOfWeek() - 2;
  if (dayOffset < 0)
    dayOffset += 7;

  // Get the duration since midnight, Tuesday.
  immutable auto duration = dateTime - DateTime(dateTime.year(),
      dateTime.month(), dateTime.day() - dayOffset, 0, 0, 0);

  // Calculate the lunar phase from the duration.
  return (duration.total!("seconds") % 4200) / 525.0;
}
