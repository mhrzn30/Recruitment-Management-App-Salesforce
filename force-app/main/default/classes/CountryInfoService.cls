public with sharing class CountryInfoService {
   private static final String API_BASE = 'https://restcountries.com/v3.1/name/';

   public class CountryInfo{

    @AuraEnabled public String name;
    @AuraEnabled public String capital;
    @AuraEnabled public String region;
    @AuraEnabled public String subregion    ;
    @AuraEnabled public String currencyName;
    @AuraEnabled public String flag;
    @AuraEnabled public String currencySymbol;
    @AuraEnabled public String timezone;
    @AuraEnabled public Long population;
    @AuraEnabled public Boolean found;

   }

    @AuraEnabled(cacheable=true)
    public static CountryInfo getCountryInfo(String countryName){
        CountryInfo result = new CountryInfo();
        result.found = false;

        if(String.isBlank(countryName)) return result;

        try{

            String cleanName = extractCountry(countryName);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(
                API_BASE + EncodingUtil.urlEncode(cleanName, 'UTF-8') +
                '?fullText=false&fields=' +
                'name,capital,region,subregion,' +
                'currencies,flags,timezones,population'
            );
            req.setMethod('GET');
            req.setTimeout(10000);

            HttpResponse res = new Http().send(req);

            if(res.getStatusCode() == 200){
                result = parseResponse(res.getBody());
                result.found = true;
            }else{
                result.found = false;
            }
        }catch(Exception e){
            System.debug('CountryInfoService error: ' + e.getMessage());
            result.found = false;
        }
        return result;
        
    }


    private static String extractCountry(String location) {
        // handle "Kathmandu, Nepal" → "Nepal"
        // handle "Remote" → "Remote"
        // handle "Nepal" → "Nepal"
        if(location.contains(',')) {
            List<String> parts = location.split(',');
            return parts[parts.size() - 1].trim();
        }
        return location.trim();
    }

    private static CountryInfo parseResponse(String body) {
        CountryInfo info = new CountryInfo();

        try {
            // response is an array — get first result
            List<Object> countries =
                (List<Object>)JSON.deserializeUntyped(body);

            if(countries.isEmpty()) {
                info.found = false;
                return info;
            }

            Map<String, Object> country =
                (Map<String, Object>)countries[0];

            // name
            Map<String, Object> nameObj =
                (Map<String, Object>)country.get('name');
            info.name = (String)nameObj.get('common');

            // capital
            List<Object> capitals =
                (List<Object>)country.get('capital');
            info.capital = capitals != null && !capitals.isEmpty()
                ? (String)capitals[0]
                : '—';

            // region
            info.region = (String)country.get('region');
            info.subregion = (String)country.get('subregion');

            // population
            info.population = country.get('population') != null
                ? Long.valueOf(
                    String.valueOf(country.get('population')))
                : null;

            // currency
            Map<String, Object> currencies =
                (Map<String, Object>)country.get('currencies');
            if(currencies != null && !currencies.isEmpty()) {
                String currencyCode =
                    (String)currencies.keySet().iterator().next();
                Map<String, Object> currencyDetails =
                    (Map<String, Object>)currencies.get(
                        currencyCode);
                info.currencyName = currencyCode + ' — ' +
                    (String)currencyDetails.get('name');
                info.currencySymbol =
                    (String)currencyDetails.get('symbol');
            }

            // timezone
            List<Object> timezones =
                (List<Object>)country.get('timezones');
            info.timezone = timezones != null &&
                !timezones.isEmpty()
                ? (String)timezones[0]
                : '—';

            // flag emoji
            Map<String, Object> flags =
                (Map<String, Object>)country.get('flags');
            info.flag = flags != null
                ? (String)flags.get('alt')
                : '—';

            info.found = true;

        } catch(Exception e) {
            System.debug('Parse error: ' + e.getMessage());
            info.found = false;
        }

        return info;
    }

}