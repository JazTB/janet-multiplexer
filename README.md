# A fiber/thread multiplexer for Janet
Executes functions asynchronously as fibers, spreading them across multiple threads

This was made for fun, don't trust it in production.

### Usage
To create a new multiplexer, run:
```janet
(import fiber-multiplexer :as mux)
...
(mux/mux capacity)
```
Where capacity is the number of fibers you want to be allowed per thread at any given time.

`mux` returns a channel which you can communicate with the multiplexer through, for example:
```janet
(def test-multiplexer (mux 2)) # allows 2 fibers per thread

(defn dummy-fn [] (forever)) # a dummy function that just loops forever

# if the channel is given a function, it is run async on a thread
# for example:
# these two are on one thread
(ev/give test-multiplexer dummy-fn)
(ev/give test-multiplexer dummy-fn)
# this will be run on a new thread
(ev/give test-multiplexer dummy-fn)

# this will make the multiplexer forcibly close all fibers and exit itself
# :exit instead of :force-exit will close the multiplexer while waiting for fibers to exit themselves,
# however this is currently broken (will just wait forever)
(ev/give test-multiplexer :force-exit)
```
