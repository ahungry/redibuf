var protobuf = require('protobufjs')
var redis = require('redis')
var client = redis.createClient()
var sub = redis.createClient(), pub = redis.createClient()
var msg_count = 0
var MathMessage

protobuf.load('../math.proto', function (err, root) {
  if (err)
    throw err

  // Obtain a message type
  MathMessage = root.lookupType('tutorial.Math')

  initRedis()
  // // Exemplary payload
  // var payload = { mathField: 'MathString' }

  // // Verify the payload if necessary (i.e. when possibly incomplete or invalid)
  // var errMsg = MathMessage.verify(payload)
  // if (errMsg)
  //   throw Error(errMsg)

  // // Create a new message
  // var message = MathMessage.create(payload) // or use .fromObject if conversion is necessary

  // // Encode a message to an Uint8Array (browser) or Buffer (node)
  // var buffer = MathMessage.encode(message).finish()
  // // ... do something with buffer

  // // Decode an Uint8Array (browser) or Buffer (node) to a message
  // var message = MathMessage.decode(buffer)
  // // ... do something with message

  // // If the application uses length-delimited buffers,
  // // there is also encodeDelimited and decodeDelimited.

  // // Maybe convert the message back to a plain object
  // var object = MathMessage.toObject(message, {
  //   longs: String,
  //   enums: String,
  //   bytes: String,
  //   // see ConversionOptions
  // })
})

// sub.on('subscribe', function (channel, count) {
//   pub.publish('a nice channel', 'I am sending a message.')
//   pub.publish('a nice channel', 'I am sending a second message.')
//   pub.publish('a nice channel', 'I am sending my last message.')
// })

function initRedis () {
  sub.on('message', function (channel, message) {
    console.log('sub channel ' + channel + ': ' + message)

    if (channel === 'calcs-needed') {
      const key = message
      client.lrange(key, 0, 0, (err, bytes) => {
        const buf = Buffer.from(bytes[0], 'binary')
        const obj = MathMessage.decode(buf)
        const base = obj.base.low
        const factorial = obj.factorial.low
        const doubled = obj.doubled.low
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
