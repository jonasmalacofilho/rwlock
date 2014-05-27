RWLock
======


API
---

### Creation

    new( maxReaders, ?waitLogTimeout, ?waitLogger)

### Func level

    read(func, ?wait)
    write(func, ?wait)

### Imp level

    // read
    prepareRead(?wait)
    releaseRead()

    // write
    prepareWrite(?wait)
    releaseWrite()

    // read -> write -> read
    convertToWriting(wait)
    backToReading()

### Low level

Don't use. Is only exposed if READ_WRITE_LOCK_SUPER is defined.


Performance
-----------

### Definitions:

First, let's create some objets:

    k: a lock
    R: number of readers
    W: number of writers
    
For simplificity, suppose we have 1 operation/reader and 1 operation/writer.
    
What about the relationship between reading and writing times (complexity)?
Open for now ...

    tr = ?
    tw = ?
    tr ? tw

...

Good benefits for readers but, for writers, it depends on server contention.
