# NOBS Founder Support Setup

Use Stripe Payment Links for the first donation path. Keep the wording as
founder support, not tax-deductible donation.

## Stripe Payment Link

Active Payment Link:

- `https://donate.stripe.com/5kQ00kclUcmTgLe2ol6g800`

Stripe setup:

- Name: `NOBS Founder Support`
- Description: `Optional support for NOBS beta hosting, Apple developer costs, testing devices, security reviews, and beta infrastructure. This does not purchase automatic Tank access.`
- Amount: let the supporter choose, or use fixed options like `$5`, `$15`, `$50`, and `$100`.
- Customer fields: collect email.
- Payment methods: card, Apple Pay, Link, and Google Pay where Stripe enables them.
- Confirmation message: `Thank you for supporting the NOBS beta. Founder support does not grant automatic Tank access.`

## Site Wire-Up

The site now routes founder support through `/donate.html`, which links to the
active Stripe Payment Link above.

## Guardrails

- Do not call this tax-deductible.
- Do not promise Tank access.
- Do not imply payment is required for beta consideration.
- Keep Tank access invite-only until billing and capacity are ready.
