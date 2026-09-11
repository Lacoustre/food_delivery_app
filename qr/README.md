# QR codes — tasteofafricancuisine.com

All three encode `https://tasteofafricancuisine.com` and nothing else. No
tracking redirect, no third-party shortener: the code points straight at the
site, so it keeps working for as long as the domain does and nobody else can
switch where it leads.

| File | Use |
|---|---|
| `tasteofafricancuisine.svg` | **print** — vector, scales to any size cleanly |
| `tasteofafricancuisine.png` | digital, 1640px |
| `tasteofafricancuisine-logo.png` | same code with the logo centred |

Error correction is level H, tolerating roughly 30% damage. That is what lets
the logo sit in the middle, and it is why the code still scans after a year of
being wiped down on a table.

## Before printing any quantity

**Scan each one with a real phone** — iPhone camera and an Android — and check
it opens the site. A QR code that fails is only discovered after the print run.

**The site must be deployed and the domain pointed at it first.** The apex
currently serves a Wix 404, so these resolve to an error page until that is
changed. See docs/resend-dns-setup.md for the A and CNAME records.

## Sizing

Smallest reliable print is about 2cm square for a phone held 20-30cm away. For
a table tent or window sticker, 5cm or more. Leave the white border — it is
part of the code, and cropping it is the usual reason a design-led reprint
stops scanning.

## Not the same as the Clover codes

Jim Augeri emailed two QR codes that point at `tasteofafrican.cloveronline.com`
— Clover's own hosted ordering page, a separate site with its own menu and its
own payments. Anything already printed with those sends customers there, not
here.
