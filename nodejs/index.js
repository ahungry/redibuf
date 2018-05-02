const protobuf = require('protobufjs')
const redis = require('redis')
const client = redis.createClient()
const sub = redis.createClient(), pub = redis.createClient()
const msg_count = 0
let MathMessage

// Load up the protobuf definition
protobuf.load('../math.proto', function (err, root) {
  if (err)
    throw err

  // Obtain a message type
  MathMessage = root.lookupType('tutorial.Math')
  initRedis()
})

// Hook into redis (localhost:6379)
function initRedis () {
  sub.on('message', function (channel, message) {
    console.log('sub channel ' + channel + ': ' + message)

    if (channel === 'calcs-needed') {
      const key = message

      // Always pull the left most list item.
      client.lrange(key, 0, 0, (err, bytes) => {
        const buf = Buffer.from(bytes[0], 'binary')
        const obj = MathMessage.decode(buf)
        console.log('Received obj: ', obj)

        // At this point, we have a Math object with a base number
        // Our job is to calculate the 'tripled' value (other system does factorial + doubled)
        const base = obj.base.low
        const factorial = undefined
        const doubled = undefined
        const tripled = base * 3
        const payload = { base, tripled, factorial, doubled }
        console.log(payload)

        const errMsg = MathMessage.verify(payload)

        if (!errMsg) {
          const message = MathMessage.create(payload)
          console.log(message)
          const buffer = MathMessage.encode(message).finish()
          console.log(buffer, buffer.toString('binary'))

          // Inform requesters it is all done.
          client.lpush(key, buffer.toString('binary'))
          pub.publish('calcs-done', key)
        }
      })
    }
  })

  sub.subscribe('calcs-needed')
}
