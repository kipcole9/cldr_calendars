defmodule Cldr.Calendar.Base.Week do
  alias Cldr.Calendar.Config
  alias Calendar.ISO
  alias Cldr.Math

  @days_in_week 7
  @weeks_in_quarter 13
  @months_in_quarter 3
  @weeks_in_long_year 53
  @weeks_in_normal_year 52
  @months_in_year 12

  defmacro __using__(options \\ []) do
    quote bind_quoted: [options: options] do
      @options options
      @before_compile Cldr.Calendar.Compiler.Week
    end
  end

  def valid_date?(year, week, day, config) do
    week <= weeks_in_year(year, config) and day in 1..days_in_week()
  end

  def year_of_era(year, config) do
    year
    |> Cldr.Calendar.ending_gregorian_year(config)
    |> Calendar.ISO.year_of_era
  end

  # Quarters are 13 weeks but if there
  # are 53 weeks in a year then 4th
  # quarter is longer
  def quarter_of_year(_year, @weeks_in_long_year, _day, _config) do
    4
  end

  def quarter_of_year(_year, week, _day, _config) do
    div(week - 1, @weeks_in_quarter) + 1
  end

  def month_of_year(_year, @weeks_in_long_year, _day, _config) do
    +12
  end

  def month_of_year(year, week, day, config) do
    %Config{weeks_in_month: {m1, m2, m3}} = config
    {m1, m2, m3} = {m1, m1 + m2, m1 + m2 + m3}
    quarter = quarter_of_year(year, week, day, config)
    offset_month = (quarter - 1) * @months_in_quarter
    week_in_quarter = Math.amod(week, @weeks_in_quarter)

    cond do
      week_in_quarter <= m1 ->
        offset_month + 1

      week_in_quarter <= m2 ->
        offset_month + 2

      week_in_quarter <= m3 ->
        offset_month + 3
    end
  end

  def week_of_year(year, week, _day, _config) do
    {year, week}
  end

  def iso_week_of_year(year, week, day, config) do
    {:ok, date} = Date.new(year, week, day, config.calendar)
    {:ok, %{year: year, month: month, day: day}} = Date.convert(date, Cldr.Calendar.Gregorian)
    Cldr.Calendar.Gregorian.iso_week_of_year(year, month, day)
  end

  def day_of_era(year, week, day, config) do
    {:ok, date} = Date.new(year, week, day, config.calendar)
    {:ok, %{year: year, month: month, day: day}} = Date.convert(date, Calendar.ISO)
    Calendar.ISO.day_of_era(year, month, day)
  end

  def day_of_year(year, week, day, config) do
    start_of_year = first_gregorian_day_of_year(year, config)
    this_day = first_gregorian_day_of_year(year, config) + week_to_days(week) + day
    this_day - start_of_year + 1
  end

  def day_of_week(_year, _week, day, config) do
    first_day = config.first_day
    Math.amod(first_day + day, days_in_week())
  end

  def months_in_year(year, _config) do
    Calendar.ISO.months_in_year(year)
  end

  def weeks_in_year(year, config) do
    if long_year?(year, config), do: @weeks_in_long_year, else: @weeks_in_normal_year
  end

  def days_in_year(year, config) do
    if long_year?(year, config) do
      @weeks_in_long_year * @days_in_week
    else
      @weeks_in_normal_year * @days_in_week
    end
  end

  def days_in_month(_year, month, config) when month in 1..11 do
    %Config{weeks_in_month: weeks_in_month} = config
    month_in_quarter = Math.amod(rem(month, @months_in_quarter), @months_in_quarter)
    elem(weeks_in_month, month_in_quarter - 1) * days_in_week()
  end

  def days_in_month(year, @months_in_year, config) do
    %Config{weeks_in_month: {_, _, weeks_in_month}} = config

    if long_year?(year, config) do
      (weeks_in_month + 1) * days_in_week()
    else
      weeks_in_month * days_in_week()
    end
  end

  def days_in_week do
    @days_in_week
  end

  def days_in_week(_year, _week) do
    @days_in_week
  end

  def year(year, config) do
    with {:ok, first_day} <- Date.new(year, 1, 1, config.calendar),
         {:ok, last_day} <- Date.new(year, weeks_in_year(year, config), days_in_week(), config.calendar) do
      Date.range(first_day, last_day)
    end
  end

  def quarter(year, quarter, config) do
    starting_week = ((quarter - 1) * @weeks_in_quarter) + 1
    ending_week = starting_week + @weeks_in_quarter - 1

    with {:ok, first_day} <- Date.new(year, starting_week, 1, config.calendar),
         {:ok, last_day} <- Date.new(year, ending_week, days_in_week(), config.calendar) do
      Date.range(first_day, last_day)
    end
  end

  def month(_year, _month, _config) do

  end

  def week(year, week, config) do
    with {:ok, first_day} <- Date.new(year, week, 1, config.calendar),
         {:ok, last_day} <- Date.new(year, week, days_in_week(), config.calendar) do
      Date.range(first_day, last_day)
    end
  end

  def plus(year, week, day, config, :quarters, quarters) do
    weeks = (quarters * @weeks_in_quarter)
    plus(year, week, day, config, :weeks, weeks)
  end

  def plus(_year, _week, _day, _config, :months, _months) do

  end

  @doc """
  Returns the `iso_days` that is the first
  gregorian day of the `year`.
  """
  def first_gregorian_day_of_year(year, %Config{first_or_last: :first} = config) do
    %{month: first_month, day: first_day, min_days: min_days} = config
    iso_days = ISO.date_to_iso_days(year, first_month, min_days)
    day_of_week = Cldr.Calendar.iso_days_to_day_of_week(iso_days)

    # The iso_days calulation is the last possible first day of the first week
    # All starting days are less than or equal to this day
    if first_day > day_of_week do
       iso_days + (first_day - days_in_week() - day_of_week)
    else
      iso_days - (day_of_week - first_day)
    end
  end

  def first_gregorian_day_of_year(year, %Config{first_or_last: :last} = config) do
    last_gregorian_day_of_year(year - 1, config) + 1
  end

  def last_gregorian_day_of_year(year, %Config{first_or_last: :first} = config) do
    first_gregorian_day_of_year(year + 1, config) - 1
  end

  def last_gregorian_day_of_year(year, %Config{first_or_last: :last} = config) do
    year = Cldr.Calendar.ending_gregorian_year(year, config)
    %{month: last_month, day: last_day, min_days: min_days} = config
    days_in_last_month = ISO.days_in_month(year, last_month)
    iso_days = ISO.date_to_iso_days(year, last_month, days_in_last_month - min_days)
    day_of_week = Cldr.Calendar.iso_days_to_day_of_week(iso_days)

    if last_day <= day_of_week do
      iso_days - (day_of_week - last_day) + 7
    else
      iso_days - (day_of_week - last_day)
    end
  end

  def long_year?(year, %Config{} = config) do
    first_day = first_gregorian_day_of_year(year, config)
    last_day = last_gregorian_day_of_year(year, config)
    days_in_year = last_day - first_day + 1
    div(days_in_year, days_in_week()) == @weeks_in_long_year
  end

  def date_to_iso_days(year, week, day, config) do
    {days, _day_fraction} = naive_datetime_to_iso_days(year, week, day, 0, 0, 0, {0, 6}, config)
    days
  end

  def date_from_iso_days(iso_day_number, config) do
    {year, week, day, _, _, _, _} = naive_datetime_from_iso_days({iso_day_number, {0, 6}}, config)
    Date.new(year, week, day, config.calendar)
  end

  def date_to_string(year, week, day) do
    "#{year}-W#{lpad(week)}-#{day}"
  end

  def naive_datetime_from_iso_days({days, day_fraction}, config) do
    {year, _month, _day} = Calendar.ISO.date_from_iso_days(days)
    first_day = first_gregorian_day_of_year(year, config)
    {year, first_day} =
      cond do
        first_day > days ->
          {year - 1, first_gregorian_day_of_year(year - 1, config)}
        (days - first_day + 1) > config.calendar.days_in_year(year) ->
          {year + 1, first_gregorian_day_of_year(year + 1, config)}
        true ->
          {year, first_day}
      end

    day_of_year = days - first_day + 1
    week = trunc(Float.ceil(day_of_year / days_in_week()))
    day = day_of_year - ((week - 1) * days_in_week())

    {hour, minute, second, microsecond} = Calendar.ISO.time_from_day_fraction(day_fraction)
    {year, week, day, hour, minute, second, microsecond}
  end

  def naive_datetime_to_iso_days(year, week, day, hour, minute, second, microsecond, config) do
    days = first_gregorian_day_of_year(year, config) + week_to_days(week) + day - 1
    day_fraction = Calendar.ISO.time_to_day_fraction(hour, minute, second, microsecond)
    {days, day_fraction}
  end

  def datetime_to_string(
        year,
        month,
        day,
        hour,
        minute,
        second,
        microsecond,
        time_zone,
        zone_abbr,
        utc_offset,
        std_offset
      ) do
    date_to_string(year, month, day) <>
      " " <>
      Calendar.ISO.time_to_string(hour, minute, second, microsecond) <>
      Cldr.Calendar.offset_to_string(utc_offset, std_offset, time_zone) <>
      Cldr.Calendar.zone_to_string(utc_offset, std_offset, zone_abbr, time_zone)
  end

  defp lpad(week) when week < 10 do
    "0#{week}"
  end

  defp lpad(week) do
    week
  end

  defp week_to_days(week) do
    (week - 1) * days_in_week()
  end
end
