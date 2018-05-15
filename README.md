---
labels:
- 'Stage-Beta'
summary: Stores geoip and client of users aggregated on a monthly basis
---

Description
===========

The goal of this module is to store a few data points about users of the
server, but in a way that is privacy preserving.

This module stores monthly counts for two pieces of data about users on the
server:

1. GeoIP location - the number of unique users per-month seen at a particular (Country, Subdivision, City) tuple.
2. Client type - the number of unique users whose resource string match a certain regex pattern.

Additionally, a single year-month pair is stored on per-user basis that
represents the last month the user was considered in the aggregate counts. This
allows the module to only increment the counts for a user once per month.

The data is collected on first-login of the user in that month.

#### Monthly totals data

Here is an example of the collected data:

```lua
-- monthly-visitors.dat
return {
  ["2018-05"] = {
    ["geo-DE-HE-2925533"] = 2;
    ["geo-AT-9-2761369"] = 1;
    ["geo-US-TX-5525577"] = 1;
    ["geo-CN-?-?"] = 1;
    ["client-ANDROID"] = 2;
    ["client-?"] = 1;
    ["client-IOS"] = 2;
  };
};
```

You can see that data is keyed per month (`2018-05`), and there is a subkey per
client type and geo tuple.

The geo tuple is prefixed with `geo-` and is made up of three hyphen delimited
parts: 

1. Country ISO code
2. Subdivision ISO code
3. City geoname id

If one of the parts is unknown it is marked as `?`.

The client data is prefixed with `client-` followed by the category as matched
by the client patterns (see configuration section).

##### Per-user data

Here is an example of what is stored per-user:

```lua
-- monthly-visitors/username.dat 
return {
  ["last-recorded"] = "2018-05";
};
```

That's it.

Installation
============

As with all modules, copy it to your plugins directory and then add it to the
`modules_enabled` list:

```lua
modules_enabled = 
    -- ... other modules
      "monthly_visitors",
}
```

#### Dependencies

This module depends on:

* [`mmdblua`][mmdblua] >= 0.2 - reads the maxmind database format
* [`compat53`][compat53]  >= 0.3 - dependency of mmdblua (available in debian stretch as lua-compat53)

#### GeoIP Database

You must have a geoip database in MaxMind DB format ([a free one
is available][geoip]).

Place the `.mmdb` file somewhere on disk where prosody can read it, such as
`/var/lib/prosody`. Be sure to chown it if necessary.


Configuration
=============

  Option                                   Default   Description
  --------------------------------------   --------- ---------------------------------------------------------------------------------------------------------------
  `mod_monthly_visitors_mmdb_path`         ``        The path to the GeoIp database in mmdb format.
  `mod_monthly_visitors_client_patterns`   `{}`      A table of regex keys and client type values.

Example of `mod_monthly_visitors_client_patterns`:

```lua

local client_patterns = {};
client_patterns["^zom%d+.*"] = "IOS";
client_patterns["^Zom-.*"] = "IOS";
client_patterns["^chatsecure%d+.*"] = "IOS";
client_patterns["^ChatSecureZom-.*"] = "ANDROID";
client_patterns["^Conversations%..*"] = "ANDROID";

mod_monthly_visitors_client_patterns = client_patterns;

```

Roadmap
=======

In the future I would like to add:

* Automatic deletion of the aggregate stats after a certain date, or perhaps a
  prosodyctl command for this.

Compatibility
=============

Tested on 0.10.0.

[geoip]: https://dev.maxmind.com/geoip/geoip2/geolite2/
[mmdblua]: https://github.com/daurnimator/mmdblua/releases
[compat53]: https://github.com/keplerproject/lua-compat-5.3
