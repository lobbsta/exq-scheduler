defmodule ExqScheduler.Schedule.ScheduleOpts do
  defstruct first_at: nil, last_at: nil

  def new(opts) do
    %__MODULE__{
      first_at: Map.get(opts, :first_at),
      last_at: Map.get(opts, :last_at)
    }
  end
end

defmodule ExqScheduler.Schedule.TimeRange do
  defstruct t_start: nil, t_end: nil
end

defmodule ExqScheduler.Schedule do
  alias Exq.Support.Job
  alias ExqScheduler.Schedule.ScheduleOpts
  alias Crontab.CronExpression
  alias Crontab.Scheduler

  @enforce_keys [:name, :cron, :job]
  defstruct name: nil, cron: nil, job: nil, schedule_opts: nil, first_run: nil, last_run: nil

  def new(name, cron_str, job, schedule_opts \\ %{}) when is_binary(job) do
    {:ok, cron} = CronExpression.Parser.parse(cron_str)

    %__MODULE__{
      name: name,
      cron: cron,
      job: Job.decode(job),
      schedule_opts: ScheduleOpts.new(schedule_opts)
    }
  end

  def encode(schedule) do
    schedule.job
    |> Map.merge(%{cron: build_encoded_cron(schedule)})
    |> Poison.encode!()
  end

  def get_jobs(schedule, time_range) do
    next_dates = get_next_run_dates(schedule.cron, time_range.t_end)
    prev_dates = get_previous_run_dates(schedule.cron, time_range.t_start)

    Enum.concat(prev_dates, next_dates)
    |> Enum.map(fn date -> {date, schedule.job} end)
  end

  defp get_next_run_dates(cron, upper_bound_date) do
    now = Timex.now() |> Timex.to_naive_datetime()
    enum = Scheduler.get_next_run_dates(cron, now)
    collect_till = &(Timex.compare(&1, upper_bound_date) != 1)
    reduce_dates(enum, collect_till)
  end

  defp get_previous_run_dates(cron, lower_bound_date) do
    now = Timex.now() |> Timex.to_naive_datetime()
    enum = Scheduler.get_previous_run_dates(cron, now)
    collect_till = &(Timex.compare(&1, lower_bound_date) != -1)
    reduce_dates(enum, collect_till)
  end

  defp reduce_dates(enum, collect_till) do
    Stream.take_while(enum, collect_till)
    |> Enum.to_list()
  end

  defp build_encoded_cron(schedule) do
    [schedule.cron, schedule.schedule_opts]
  end
end
