import ipaddress
import logging

import requests

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# URL to fetch CloudFront IP ranges
CLOUDFRONT_IP_RANGES_URL = "https://d7uri8nf7uskq.cloudfront.net/tools/list-cloudfront-ips"


def fetch_cloudfront_ips():
    response = requests.get(CLOUDFRONT_IP_RANGES_URL)
    ip_ranges = response.json()
    cloudfront_ips = ip_ranges['CLOUDFRONT_GLOBAL_IP_LIST'] + ip_ranges['CLOUDFRONT_REGIONAL_EDGE_IP_LIST']
    return cloudfront_ips


def lambda_handler(event, context):
    logger.info(f"Event: {event}")

    response = {
        "isAuthorized": False,
        "context": {
            "stringKey": "value",
            "numberKey": 1,
            "booleanKey": True,
            "arrayKey": ["value1", "value2"],
            "mapKey": {"value1": "value2"}
        }
    }

    try:
        # Fetch the latest CloudFront IP ranges
        cloudfront_ips = fetch_cloudfront_ips()
        logger.info(f"Fetched CloudFront IP ranges: {cloudfront_ips}")

        # Extract the x-forwarded-for header
        x_forwarded_for = event['headers'].get('x-forwarded-for', '')
        ip_list = [ip.strip() for ip in x_forwarded_for.split(',')]
        logger.info(f"IP List from x-forwarded-for: {ip_list}")

        # Extract the Origin header
        origin_header = event['headers'].get('origin', '')
        logger.info(f"Origin Header: {origin_header}")

        # List of allowed origins (your CloudFront distribution URL)
        allowed_origins = ["https://dreamcanvas.brewsentry.com"]

        # Check if the last IP in x-forwarded-for is in the allowed CloudFront IP ranges
        ip_allowed = ip_list and any(
            ipaddress.ip_address(ip_list[-1]) in ipaddress.ip_network(cidr) for cidr in cloudfront_ips)
        origin_allowed = origin_header in allowed_origins

        if ip_allowed and origin_allowed:
            response["isAuthorized"] = True
            logger.info("allowed")
        else:
            logger.info("denied")

    except Exception as e:
        logger.error(f"Error in authorizer: {e}")
        logger.info("denied")

    return response
