@isTest
public class CountryInfoMock
    implements HttpCalloutMock {

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/json');
        res.setBody('[{' +
            '"name": {"common": "Nepal"},' +
            '"capital": ["Kathmandu"],' +
            '"region": "Asia",' +
            '"subregion": "Southern Asia",' +
            '"population": 29136808,' +
            '"currencies": {' +
                '"NPR": {' +
                    '"name": "Nepalese rupee",' +
                    '"symbol": "Rs"' +
                '}' +
            '},' +
            '"timezones": ["UTC+05:45"],' +
            '"flags": {' +
                '"alt": "The flag of Nepal"' +
            '}' +
        '}]');
        return res;
    }
}