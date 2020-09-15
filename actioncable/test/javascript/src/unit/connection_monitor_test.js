import * as ActionCable from "../../../../app/javascript/action_cable/index"

const {module, test} = QUnit

module("ActionCable.ConnectionMonitor", hooks => {
  let monitor
  hooks.beforeEach(() => monitor = new ActionCable.ConnectionMonitor({}))

  module("#getPollInterval", hooks => {
    hooks.beforeEach(() => { Math._random = Math.random })
    hooks.afterEach(() => { Math.random = Math._random })

    const staleThreshold = ActionCable.ConnectionMonitor.staleThreshold
    const {min, max, base, jitter} = ActionCable.ConnectionMonitor.pollInterval
    const ms = 1000

    test("uses staleThreshold when 0 reconnection attempts", assert => {
      Math.random = () => 0
      assert.equal(monitor.getPollInterval(), staleThreshold * ms)

      Math.random = () => 0.5
      assert.equal(monitor.getPollInterval(), 1.5 * staleThreshold * ms)
    })

    test("uses exponential backoff when >0 reconnection attempts", assert => {
      Math.random = () => 0

      monitor.reconnectAttempts = 1
      assert.equal(monitor.getPollInterval(), min * base * ms)

      monitor.reconnectAttempts = 2
      assert.equal(monitor.getPollInterval(), min * base * base * ms)
    })

    test("applies pollInterval.max to exponential backoff", assert => {
      Math.random = () => 0

      monitor.reconnectAttempts = 9001
      assert.equal(monitor.getPollInterval(), max * ms)
    })

    test("applies pollInterval.jitter to exponential backoff", assert => {
      monitor.reconnectAttempts = 1

      Math.random = () => 0.5
      assert.equal(monitor.getPollInterval(), min * base * (1 + jitter * 0.5) * ms)

      Math.random = () => 0.25
      assert.equal(monitor.getPollInterval(), min * base * (1 + jitter * 0.25) * ms)
    })

    test("applies pollInterval.jitter after pollInterval.max", assert => {
      monitor.reconnectAttempts = 9001

      Math.random = () => 0.5
      assert.equal(monitor.getPollInterval(), max * (1 + jitter * 0.5) * ms)
    })
  })
})
