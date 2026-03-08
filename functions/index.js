/**
 * Firebase Cloud Function — Stripe Payment Intent
 * ─────────────────────────────────────────────────
 * Deploy: firebase deploy --only functions
 *
 * Install deps first:
 *   cd functions && npm install stripe cors
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const Stripe = require("stripe");
const cors = require("cors")({origin: true});

admin.initializeApp();

// ✅ Set your Stripe SECRET key in Firebase config:
//    firebase functions:config:set stripe.secret="sk_test_YOUR_SECRET_KEY"
const stripe = new Stripe(functions.config().stripe.secret, {
  apiVersion: "2023-10-16",
});

/**
 * POST /createPaymentIntent
 * Body: { amount: number, currency: string, description: string }
 * Returns: { clientSecret: string }
 */
exports.createPaymentIntent = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== "POST") {
      return res.status(405).json({error: "Method not allowed"});
    }

    try {
      const {amount, currency = "inr", description = "EV Slot Booking"} =
        req.body;

      if (!amount || isNaN(amount)) {
        return res.status(400).json({error: "Invalid amount"});
      }

      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(amount), // paise (e.g. 5000 = ₹50)
        currency,
        description,
        automatic_payment_methods: {enabled: true},
        metadata: {
          app: "EVChargingFinder",
        },
      });

      return res.status(200).json({
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      });
    } catch (err) {
      console.error("Stripe error:", err);
      return res.status(500).json({error: err.message});
    }
  });
});
