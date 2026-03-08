const express = require("express");
const cors = require("cors");
const Stripe = require("stripe");
require("dotenv").config();

const app = express();
const stripe = Stripe(process.env.STRIPE_SECRET_KEY);

app.use(cors());
app.use(express.json());

// ─────────────────────────────────────────────
//  POST /create-payment-intent
// ─────────────────────────────────────────────
app.post("/create-payment-intent", async (req, res) => {
  try {
    const {
      amount,                        // ✅ NO default — must come from Flutter
      currency = "inr",
      description = "EV Slot Booking",
    } = req.body;

    // ✅ parseInt, not isNaN on raw value — catches strings, floats, nulls
    const parsedAmount = parseInt(amount, 10);

    if (!parsedAmount || isNaN(parsedAmount) || parsedAmount <= 0) {
      return res.status(400).json({ error: `Invalid amount: ${amount}` });
    }

    console.log(`Creating PaymentIntent: ${parsedAmount} ${currency}`);

    const paymentIntent = await stripe.paymentIntents.create({
      amount: parsedAmount,          // paise for INR (e.g. 5000 = ₹50)
      currency,
      description,
      automatic_payment_methods: { enabled: true },
      metadata: { app: "EVChargingFinder" },
    });

    console.log(`✅ PaymentIntent created: ${paymentIntent.id}`);

    return res.status(200).json({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    });
  } catch (err) {
    console.error("❌ Stripe error:", err.message);
    return res.status(500).json({ error: err.message });
  }
});

// ─────────────────────────────────────────────
//  POST /webhook
// ─────────────────────────────────────────────
app.post(
  "/webhook",
  express.raw({ type: "application/json" }),
  (req, res) => {
    const sig = req.headers["stripe-signature"];
    let event;

    try {
      event = stripe.webhooks.constructEvent(
        req.body,
        sig,
        process.env.STRIPE_WEBHOOK_SECRET
      );
    } catch (err) {
      console.error("Webhook signature error:", err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    switch (event.type) {
      case "payment_intent.succeeded":
        console.log("✅ Payment succeeded:", event.data.object.id);
        break;
      case "payment_intent.payment_failed":
        console.log("❌ Payment failed:", event.data.object.id);
        break;
      default:
        console.log(`Unhandled event: ${event.type}`);
    }

    res.json({ received: true });
  }
);

app.get("/", (_, res) => res.send("EV Charging Backend Running 🚀"));
app.get("/health", (_, res) => res.json({ status: "ok" }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () =>
  console.log(`🚀 EV Charging backend running on port ${PORT}`)
);