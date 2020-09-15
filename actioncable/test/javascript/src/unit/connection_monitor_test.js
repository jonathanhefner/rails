import * as ActionCable from "../../../../app/javascript/action_cable/index"

const {module, test} = QUnit

module("ActionCable.ConnectionMonitor", hooks => {
  let monitor
  hooks.beforeEach(() => monitor = new ActionCable.ConnectionMonitor({}))

  module("#getPollInterval", hooks => {
    hooks.beforeEach(() => {
      Math._random = Math.random
      Date.prototype._getTime = Date.prototype.getTime
    })
    hooks.afterEach(() => {
      Math.random = Math._random
      Date.prototype.getTime = Date.prototype._getTime
    })

    const staleThreshold = ActionCable.ConnectionMonitor.staleThreshold
    const {min, max, base, jitter} = ActionCable.ConnectionMonitor.pollInterval
    const ms = 1000

    test("uses staleThreshold when 0 reconnection attempts", assert => {
      Math.random = () => 0
      Date.prototype.getTime = () => 1
      monitor.recordPing()

      assert.equal(monitor.getPollInterval(), staleThreshold * ms)

      Date.prototype.getTime = () => 1001
      assert.equal(monitor.getPollInterval(), staleThreshold * ms - 1000)
    })

    test("applies random delay after staleThreshold", assert => {
      Date.prototype.getTime = () => 1
      monitor.recordPing()

      Math.random = () => 0.5
      assert.equal(monitor.getPollInterval(), staleThreshold * ms + min * ms)

      Math.random = () => 0.25
      assert.equal(monitor.getPollInterval(), staleThreshold * ms + min * ms / 2)
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
