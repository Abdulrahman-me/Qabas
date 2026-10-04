// The pinned sidecar has no cache-disable flag: NodeCache stdTTL=0 means infinite caching.
// Load before server.js without altering the pinned checkout. D-91 applies to this cache too.
const NodeCache = require(require.resolve('node-cache', { paths: [process.cwd()] }));
NodeCache.prototype.has = function () { return false; };
NodeCache.prototype.get = function () { return undefined; };
NodeCache.prototype.set = function () { return true; };
NodeCache.prototype.mget = function () { return {}; };
NodeCache.prototype.mset = function () { return true; };
