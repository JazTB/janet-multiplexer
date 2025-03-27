# fiber/thread multiplexer for Janet

(var logger-active? false)

(defn- log [& args] # debug printf, can be set to return nil if unneeded
  (when logger-active?
    (apply print args)))

(defn- subfiber
  [fun]
  (fiber/new |(fun) :e))

(defn- supervisor
  [channel] # accepts a max capacity and a channel
  (def- memory @[]) # all fibers to be used
  (defn- is-alive? [fib]
    (def- st (fiber/status fib))
    (or (= st :alive) (= st :pending) (= st :suspended) (= st :new)))
  (defn- num-alive []
    (var n 0)
    (loop [subf :in memory]
      (when (is-alive? subf)
        (set n (+ 1 n))))
    n)
  (forever
    (def msg (ev/take channel))
    (when (keyword? msg) # handle keywords
      (when (= msg :exit) # gracefully exit (wait for all fibers to complete)
        (break))
      (when (= msg :force-exit) # forcibly exited
        (loop [f :in (ev/all-tasks)]
          (ev/cancel f "Forcibly exiting supervisor."))
        (break))
      (when (= msg :count) # if asked for a count, return the number of living fibers
        (ev/give channel (num-alive))))
    (when (function? msg) # if we receive a new function, call it
      (array/push memory (subfiber msg))
      (ev/call resume (last memory))
      (log "Supervisor added new function! Alive count is now " (num-alive)))))

(defn- supervisor/new []
  (def- chn (ev/thread-chan 1024))
  (ev/spawn-thread (supervisor chn))
  chn)

(defn- multiplexer
  [capacity channel] # accepts new functions from a channel
  (def- supervisors @[])
  (defn- clean-supervisors # gets rid of empty supervisors
    []
    (var- i (- (length supervisors) 1))
    (while (>= i 0) (defer (set i (- i 1))
      (def- sup (get supervisors i))
      (ev/give sup :count)
      (def- cnt (ev/take sup))
      (when (= cnt 0) # if empty
        (log "Multiplexer removing a dead supervisor")
        (ev/give sup :exit) # close that supervisor
        (array/remove supervisors i))))) # clean it from the array
  (defn- add-function # find the first non-full supervisor, or create a new one if all are full
    [fun]
    (ev/sleep 0.01)
    (var- found false)
    (loop [sup :in supervisors]
      (ev/give sup :count)
      (def- cnt (ev/take sup))
      (when (< cnt capacity) # if not full
        (log "Multiplexer adding a function to an existing supervisor")
        (ev/give sup fun)
        (set found true)
        (break)))
    (when (not found) # we didn't find one
      (log "Multiplexer creating a new supervisor")
      (def- nsup (supervisor/new))
      (ev/give nsup fun)
      (array/push supervisors nsup))
    (ev/sleep 0.01)
    (clean-supervisors))
  (forever
    (def- msg (ev/take channel))
    (cond
      (function? msg)
        (add-function msg)
      (keyword? msg)
        (case msg
          :exit
            (break)
          :force-exit
            (do
              (loop [s :in supervisors]
                (ev/give s :force-exit))
              (break))))))

(defn- multiplexer/new
  [capacity]
  (def- chn (ev/chan 1024))
  (ev/call |(resume (fiber/new |(multiplexer capacity chn))))
  chn)

(defn mux
  "Creates a new fiber:thread multiplexer
  \n`capacity` changes how many fibers will be run per thread at any time
  \nReturns a channel to communicate to the multiplexer.
  \n`ev/give` the channel a function to run it asynchronously, or
  \ngive :exit or :force-exit to close the multiplexer."
  [capacity]
  (multiplexer/new capacity))
