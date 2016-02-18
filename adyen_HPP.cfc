/**
*   Name: Adyen Hosted Payment Page (HPP) Connector
*   Author: Nicholas Claaszen ( https://github.com/NicholasClaaszen && https://EquinoxCoding.com )
*   Date: 18/02/2016
*
*   Licensed under Creative Commons Attribution-ShareAlike 4.0 International
*   ( http://creativecommons.org/licenses/by-sa/4.0/ )
*
*   Any person dealing with the Software shall not misrepresent the source of the Software.
*
*   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
*   INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
*   PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
*   HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
*   OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
*   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

component
	hint = "Generator/Encoder for Adyen HPP transactions"
{
	public any function init(
			required string secret,
			required string skinCode,
			required string merchant,
			required string endpoint,
			string currencyCode = 'EUR',
			string shopperLocale = '',
			string countryCode = '',
			string allowedMethods = '',
			string blockedMethods = '',
			string fraudOffset = '',
			string brandCode = '',
			string issuerID = '',
			string shopperStatement = '',
			string offerEmail = '',
			string resURL = ''
	)
		hint = "Initialize this object with several always-required values"
	{
		variables.secret = arguments.secret;
		variables.skinCode = arguments.skinCode;
		variables.merchant = arguments.merchant;
		variables.endpoint = arguments.endpoint;
		variables.shopperLocale = arguments.shopperLocale;
		variables.currencyCode = arguments.currencyCode;
		variables.countryCode = arguments.countryCode;
		variables.allowedMethods = arguments.allowedMethods;
		variables.blockedMethods = arguments.blockedMethods;
		variables.fraudOffset = arguments.fraudOffset;
		variables.brandCode = arguments.brandCode;
		variables.issuerID = arguments.issuerID;
		variables.shopperStatement = arguments.shopperStatement;
		variables.offerEmail = arguments.offerEmail;
		variables.resURL = arguments.resURL;

		return this;
	}

	public string function getForm(
		required string merchantReference,
		required string paymentAmount,
		string returntype = 'struct',
		string resUrl = '',
		string merchantReturnData = '',
		string orderData = '',
		date shipBeforeDate = dateAdd( 'd', 7, now() ),
		date sessionValidity = dateAdd( 'n', 30, now() ),
		string currencyCode = '',
		string shopperLocale = '',
		string shopperEmail = '',
		string shopperReference = '',
		string shopperStatement = '',
		string offset = '',
		string offerEmail = ''
	)
		hint = "Generate a form filled with all the required hidden fields."
	{
		var result = '<form method="POST" action="' & variables.endpoint & '" class="adyenForm">';
		var data = this.generate( argumentCollection: arguments );

		for( var element in structKeyArray( data ) ) {
			result &= '<input type="hidden" name="' & element & '" value="' & data[ element ] & '"/>';
		}

		result &= '</form>';

		return result;
	}

	public string function getURL(
		required string merchantReference,
		required string paymentAmount,
		string returntype = 'struct',
		string resUrl = '',
		string merchantReturnData = '',
		string orderData = '',
		date shipBeforeDate = dateAdd( 'd', 7, now() ),
		date sessionValidity = dateAdd( 'n', 30, now() ),
		string currencyCode = '',
		string shopperLocale = '',
		string shopperEmail = '',
		string shopperReference = '',
		string shopperStatement = '',
		string offset = '',
		string offerEmail = ''
	)
		hint = "Generate a complete url with all the required params."
	{
		var result = '';
		var data = this.generate( argumentCollection: arguments );

		for( var elememt in structKeyArray( data ) ) {
			result &= '&' & urlEncodedFormat( elememt ) & '=' & urlEncodedFormat( data[ elememt ] );
		}

		result = variables.endpoint & replace( result, '&', '?' );

		return result;
	}

	public struct function generate(
			required string merchantReference,
			required string paymentAmount,
			string returntype = 'struct',
			string resUrl = '',
			string merchantReturnData = '',
			string orderData = '',
			date shipBeforeDate = dateAdd( 'd', 7, now() ),
			date sessionValidity = dateAdd( 'n', 30, now() ),
			string currencyCode = '',
			string shopperLocale = '',
			string shopperEmail = '',
			string shopperReference = '',
			string shopperStatement = '',
			string offset = '',
			string offerEmail = ''
	)
		hint = "Used internally to generate the struct for getForm() and getUrl(), can be called directly to get the original struct"
	{
		/*
			Capitalization is important!
			Add the required fields and fields we know exist
		*/
		var result = {
			'merchantReference': arguments.merchantReference,
			'paymentAmount': arguments.paymentAmount,
			'currencyCode': len( arguments.currencyCode ) ? arguments.currencyCode : variables.currencyCode,
			'shipBeforeDate': this.iso8601Date( arguments.shipBeforeDate ),
			'skinCode': variables.skinCode,
			'merchantAccount': variables.merchant,
			'sessionValidity': this.iso8601Date( arguments.sessionValidity ),
		};

		/*
			If orderData exists, it gets a special treatment
		*/
		if( len( arguments.orderData ) ) {
			result[ 'orderData' ] = this.orderData( arguments.orderData );
		}
		/*
			Check the remaining fields and add them only if they exist.
			Capitalization still important!
		*/
		var otherFields =   'shopperLocale,merchantReturnData,countryCode,shopperEmail,ShopperReference,
							allowedMethods,blockedMethods,offset,brandCode,IssuerID,shopperStatement,offerEmail,resUrl';
		for( var element in listToArray( otherFields ) ) {
			if(
				(
					structKeyExists( arguments, element )
					&& len( arguments[ element ] )
				)
				|| (
					structKeyExists( variables, element )
					&& len( variables[ element ] )
				)
			) {
				result[ '#element#' ] = len( arguments[ element ] ) ? arguments[ element ] : variables[ element ];
			}
		}

		/*
			Generate the Merchant Signature:
			https://docs.adyen.com/manuals/hpp-manual/hpp-hmac-calculation/hmac-payment-setup-sha-256
		*/
		var signature = this.generateMerchantSig( result );

		/*
			Encode the Signature and assign it to the struct
			https://docs.adyen.com/manuals/hpp-manual/hpp-hmac-calculation/hmac-payment-setup-sha-256
		*/
		result[ 'merchantSig' ] = this.encodeMerchantSig( signature );

		return result;
	}

	private string function iso8601Date( required date d = now() ) {
		/*
			Convert local time to UTC and make it ISO8601-compliant
		*/
		var t = dateConvert( 'local2utc', arguments.d );
		var result = dateFormat( t, 'yyyy-mm-dd' );
			result &= 'T';
			result &= timeFormat( t, 'HH:mm:ss' );
			result &= 'Z';
		return result;
	}

	private string function encodeOrderData( required string data )
		hint = "Encode Order data"
	{
		/*
			Shamelessly 'borrowed' from:
			https://github.com/Adyen/coldfusion
		*/
		var bos = createObject("java" , "java.io.ByteArrayOutputStream").init();
		var gzip = createObject("java" , "java.util.zip.GZIPOutputStream").init( bos );

		gzip.write( data.getBytes() );
		gzip.finish();

		var sHtml = bos.toByteArray();

		bos.close();
		gzip.close();

		return toBase64(sHtml);
	}

	private string function generateMerchantSig( required struct data ) {
		var data = arguments.data;
		var keys = structKeyArray( data );
		var result_keys = '';
		var result_vals = '';
		var result = '';

		/*
			Make sure it's sorted properly
		*/
		arraySort( keys, 'textnocase' );

		/*
			We'll be building the Signature as two strings...
		*/
		for ( var element in keys ) {
			result_keys &= replace( replace( element, '\', '\\', 'ALL' ), ':', '\:', 'ALL' ) & ':';
			result_vals &= ':' & replace( replace( data[ element ], '\', '\\', 'ALL' ), ':', '\:', 'ALL' );
		}

		/*
			...and then we'll lazily combine them.
		*/
		result = result_keys & replace( result_vals, ':', '' );

		return result;
	}

	private string function encodeMerchantSig( required string sig ) {
		/*
			Shoutout to Sean Corfield for his help on this one.
			https://docs.adyen.com/manuals/hpp-manual/hpp-hmac-calculation/hmac-payment-setup-sha-256/java-hmac-signature
		*/
		var decoder = createObject( 'java', 'javax.xml.bind.DatatypeConverter' ).parseHexBinary( variables.secret );
		var signingKey = createObject( 'java', 'javax.crypto.spec.SecretKeySpec' ).init( decoder, 'HmacSHA256' );
		var mac = createObject( 'java', 'javax.crypto.Mac' ).getInstance( 'HmacSHA256' );

		mac.init( signingKey );

		var rawHmac = mac.doFinal( toBinary( toBase64( arguments.sig ) ) );

		return toBase64( rawHmac );
	}
}
