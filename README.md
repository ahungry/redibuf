# redibuf - A mashup of Redis and Protobufs, for event sourcing POC

## Summary

```json
MathMessage {
  base: int64,
  factorial: int64,
  doubled: int64,
  tripled: int64
}
```

The object starts with just a base number, then is sent to Redis as a
shallow object with nil/undefined values for the related data.

The requester that initially inserted the object sends a Redis PUBLISH
request of the Redis LIST key.

Each service is listening on the calcs-needed CHANNEL and makes a copy
of the left-most object in the immutable object list on Redis
(LRANGE/LPUSH).

As a service computes the value/performs the work, it prepends the new
(more filled out) object onto the left side.

When all services are done, the reassembler takes the N shallow copies
to build one fully hydrated copy.  This is then served to the
requester.

![model](https://raw.githubusercontent.com/ahungry/redibuf/master/img/model.png)

## CLI
Build with `cat build.sh | sh` in the project root.

Then you can use a simple `make start` to see it in action.

Initiate a request with `curl http://localhost:5001/6`

## License
GPLv3
