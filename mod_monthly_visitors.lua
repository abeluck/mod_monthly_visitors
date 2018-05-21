local mmdb = assert(require "mmdb", "mod_monthly_visitors requires mmdb");
local mv_store_name = "monthly-visitors";
local mv_store = module:open_store(mv_store_name, "map");

local geoip_db_filename = module:get_option_string("mod_monthly_visitors_mmdb_path");
local geodb = assert(mmdb.read(geoip_db_filename), "GeoIP mmdb database not valid.");

local client_patterns = module:get_option("mod_monthly_visitors_client_patterns", {});
local unknown_client = "?";
local country_to_record_iso = module:get_option("mod_monthly_visitors_record_country", "ALL");

local function current_month()
  return os.date("%Y-%m");
end

local function geocode(ip)
  local geodata;
  if not pcall(function() geodata = geodb:search_ipv4(ip); end ) then
    return nil
  end
  local city = "?";
  if geodata["city"] ~= nil then
    city = geodata.city.geoname_id;
  end
  local subdiv = "?";
  if geodata["subdivisions"] ~= nil then
    subdiv = geodata.subdivisions[1].iso_code;
  end

  local country = "?";
  if geodata["country"] ~= nil then
    country = geodata.country.iso_code
  end

  return country .. "-" .. subdiv .. "-" .. city;
end

local function should_record(ip)
  if country_to_record_iso == "ALL" then
    return true;
  end

  local geodata;
  if not pcall(function() geodata = geodb:search_ipv4(ip); end ) then
    return false;
  end

  local country = "";
  if geodata["country"] ~= nil then
    country = geodata.country.iso_code
  end
  return country == country_to_record_iso;
end

local function has_been_recorded(username)
  local curr_month = current_month();
  local last_recorded = mv_store:get(username, "last-recorded");
  return last_recorded == curr_month;
end

local function classify(patterns, unknown, item)
  if item == nil then
    return unknown;
  end
  for pattern,category in pairs(patterns) do
    local res = string.match(item, pattern) ;
    if res ~= nil then
      return category;
    end
  end
  return unknown;
end

local function guess_client(resource)
  return classify(client_patterns, unknown_client, resource);
end

local function incr_key(mv_data, key)
  if key == nil then
    return mv_data;
  end;
  if mv_data[key] ~= nil then
    mv_data[key] = 1 + mv_data[key];
  else
    mv_data[key] = 1;
  end
  return mv_data;
end

local function record_monthly_visitor(username, ip, resource)

  if has_been_recorded(username) then
    return;
  end

  if not should_record(ip) then
    return;
  end

  local curr_month = current_month();
  local client = guess_client(resource);
  local geo_key = geocode(ip);

  local mv_data = mv_store:get(nil, curr_month);
  if mv_data == nil then
    mv_data = {};
  end

  mv_data = incr_key(mv_data, "client-" .. client);
  mv_data = incr_key(mv_data, "geo-" .. geo_key);

  -- save the current month's counts
  mv_store:set(nil, curr_month, mv_data);
  -- mark the username as recorded for this month
  mv_store:set(username, "last-recorded", curr_month);
  module:log("info", username .. " " .. curr_month);
end

module:hook("resource-bind", function (event)
              local session = event.session;
              record_monthly_visitor(session.username, session.ip, session.resource);
end);

