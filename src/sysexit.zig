pub const SysExits = enum(u7) {
    // successful termination
    EX_OK = 0,
    // command line usage error
    EX_USAGE = 64,
    // data format error
    EX_DATAERR = 65,
    // cannot open input
    EX_NOINPUT = 66,
    // addressee unknown
    EX_NOUSER = 67,
    // host name unknown
    EX_NOHOST = 68,
    // service unavailable
    EX_UNAVAILABLE = 69,
    // internal software error
    EX_SOFTWARE = 70,
    // system error (e.g., can't fork)
    EX_OSERR = 71,
    // critical OS file missing
    EX_OSFILE = 72,
    // can't create (user) output file
    EX_CANTCREAT = 73,
    // input/output error
    EX_IOERR = 74,
    // temp failure; user is invited to retry
    EX_TEMPFAIL = 75,
    // remote error in protocol
    EX_PROTOCOL = 76,
    // permission denied
    EX_NOPERM = 77,
    // configuration error
    EX_CONFIG = 78,
};
