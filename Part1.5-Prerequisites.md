# Part 1.5 - Prerequisites


This will go over a few pre-requisite services you will need.

# A note on costs and pricing
I will make no guarantee on the pricing of any of these services for your usage. However, they all offer fairly generous free tiers at the time of writing, although they may require a credit card on file to use some features. Please make sure you research the potential costs associated with any service you utilize and make an informed decision.

# A domain with cloudflare DNS
You will need a domain name you own and control where you can allow cloudflare to manage the DNS. Using cloudflare to manage the DNS allows for tunnels to be easily implemented later on and is an important pre-requisite to our lets encrypt setup.

Here is a great getting started guide from Cloudflare on everything from setting up your account to linking your domain to additional security and performance features that are available: https://developers.cloudflare.com/learning-paths/get-started/concepts/

# Sendgrid for email
This guide from sendgrid details how to setup your account for SMTP sending of email, which will allow your server to send emails to you or your users about system updates, failures, and other statuses.

https://docs.sendgrid.com/for-developers/sending-email/getting-started-smtp


# Backblaze B2

Backblaze is one of many options available to store your backups. When we get to that section of the documentation, I will link the relavant documentation to use other services; however, if you want to use backblaze, the guide is below. 


https://www.backblaze.com/docs/cloud-storage-get-started-with-the-ui


# A server
You will need something to host this setup. There are hundreds of options depending on what you want to do from a raspberry Pi, to an old laptop, to a top of the line server. If you are just toying around, you can also spin up a Virtual Machine and follow the tutorial on that system

[Previous Part - Introduction](Part1-Introduction.md) | [Next Part - Host Setup](Part2-Core.md)