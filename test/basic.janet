(use ../fiber-multiplexer/init)

(set logger-active? true)
(def mp (mux 3))
# should create 4 threads
(for c 1 9
  (ev/give mp
      |((for i 1 5
          (printf "%d" c)
          (ev/sleep 0.5))
        (printf "%d done!" c))))
(ev/sleep 5)
(ev/give mp |(ev/sleep 0.1))
(ev/sleep 5)
(ev/give mp :force-exit)
