import * as ActionCable from "../../../../app/javascript/action_cable/index"

const {module, test} = QUnit

module("ActionCable.ConnectionMonitor", () => {
  module("#getPollInterval", () => {
    const ms = 1000

    test("clamps return value", assert => {
      const {min, max} = ActionCable.ConnectionMonitor.pollInterval
      const monitor = new ActionCable.ConnectionMonitor({})

      assert.equal(monitor.getPollInterval(), min * ms)

      monitor.reconnectAttempts = 9001

      assert.equal(monitor.getPollInterval(), max * ms)
    })

    const stubRandom = (value, callback) => {
      const originalRandom = Math.random
      Math.random = () => value
      try {
        return callback()
      }
      finally {
        Math.random = originalRandom
      }
    }

    test("applies jitter", assert => {
      const baseline = ActionCable.ConnectionMonitor.pollInterval.min
      const jitter = 0.15
      const random = 0.85
      const expected = Math.round(baseline * (1 + jitter * random) * ms)

      stubRandom(random, () => {
        const monitor = new ActionCable.ConnectionMonitor({})
        assert.equal(monitor.getPollInterval(jitter), expected)
      })
    })

    test("does not clamp jitter", assert => {
      const baseline = ActionCable.ConnectionMonitor.pollInterval.max
      const jitter = 0.5
      const expected = Math.round(baseline * (1 + jitter) * ms)

      stubRandom(1, () => {
        const monitor = new ActionCable.ConnectionMonitor({})
        monitor.reconnectAttempts = 9001
        assert.equal(monitor.getPollInterval(jitter), expected)
      })
    })
  })
})
