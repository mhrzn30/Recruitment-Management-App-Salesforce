@isTest
private class CountryInfoServiceTest {

    private class CountryInfoNotFoundMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('[]');
            return res;
        }
    }

    @isTest
    static void test_getCountryInfo_success() {
        Test.setMock(HttpCalloutMock.class,
            new CountryInfoMock());

        Test.startTest();
        CountryInfoService.CountryInfo info =
            CountryInfoService.getCountryInfo('Nepal');
        Test.stopTest();

        System.assert(info.found,
            'Country should be found');
        System.assertEquals('Nepal', info.name,
            'Country name should be Nepal');
        System.assertEquals('Kathmandu', info.capital,
            'Capital should be Kathmandu');
        System.assertEquals('Asia', info.region,
            'Region should be Asia');
        System.assertEquals('UTC+05:45', info.timezone,
            'Timezone should match');
        System.assert(info.currencyName.contains('NPR'),
            'Currency should contain NPR');
    }

    @isTest
    static void test_getCountryInfo_withCityAndCountry() {
        Test.setMock(HttpCalloutMock.class,
            new CountryInfoMock());

        Test.startTest();
        // should extract "Nepal" from "Kathmandu, Nepal"
        CountryInfoService.CountryInfo info =
            CountryInfoService.getCountryInfo(
                'Kathmandu, Nepal');
        Test.stopTest();

        System.assert(info.found,
            'Should handle City, Country format');
        System.assertEquals('Nepal', info.name,
            'Should extract country from location string');
    }

    @isTest
    static void test_getCountryInfo_blankInput() {
        Test.startTest();
        CountryInfoService.CountryInfo info =
            CountryInfoService.getCountryInfo('');
        Test.stopTest();

        System.assertEquals(false, info.found,
            'Blank input should return not found');
    }

    @isTest
    static void test_getCountryInfo_notFound() {
        // mock returns 404
        Test.setMock(HttpCalloutMock.class,
            new CountryInfoNotFoundMock());

        Test.startTest();
        CountryInfoService.CountryInfo info =
            CountryInfoService.getCountryInfo(
                'InvalidCountryXYZ');
        Test.stopTest();

        System.assertEquals(false, info.found,
            '404 response should return not found');
    }

    @isTest
    static void test_getCountryInfo_remote() {
        Test.setMock(HttpCalloutMock.class,
            new CountryInfoMock());

        Test.startTest();
        CountryInfoService.CountryInfo info =
            CountryInfoService.getCountryInfo('Remote');
        Test.stopTest();

        // Remote is not a country — should handle gracefully
        System.assertNotEquals(null, info,
            'Should return result object even for Remote');
    }
}