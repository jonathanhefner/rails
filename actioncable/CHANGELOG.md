*   The Action Cable client now includes safeguards to prevent a "thundering
    herd" of client reconnects after server connectivity loss:

    * After the stale threshold is reached for a connection, there is an initial
      random delay of 0 to 2 * `ActionCable.ConnectionMonitor.pollInterval.min`
      seconds before the first reconnection attempt.
    * Subsequent reconnection attempts now use exponential backoff instead of
      logarithmic backoff.  To allow the delay between reconnection attempts to
      increase slowly at first, the default exponentiation base is < 2.
    * Random jitter is applied to each delay between reconnection attempts.

    *Jonathan Hefner*

*   `ActionCable::Connection::Base` now allows intercepting unhandled exceptions
    with `rescue_from` before they are logged, which is useful for error reporting
    tools and other integrations.

    *Justin Talbott*

*   Add `ActionCable::Channel#stream_or_reject_for` to stream if record is present, otherwise reject the connection

    *Atul Bhosale*

*   Add `ActionCable::Channel#stop_stream_from` and `#stop_stream_for` to unsubscribe from a specific stream.

    *Zhang Kang*

*   Add PostgreSQL subscription connection identificator.

    Now you can distinguish Action Cable PostgreSQL subscription connections among others.
    Also, you can set custom `id` in `cable.yml` configuration.

    ```sql
    SELECT application_name FROM pg_stat_activity;
    /*
        application_name
    ------------------------
    psql
    ActionCable-PID-42
    (2 rows)
    */
    ```

    *Sergey Ponomarev*

*   Subscription confirmations and rejections are now logged at the `DEBUG` level instead of `INFO`.

    *DHH*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/actioncable/CHANGELOG.md) for previous changes.
