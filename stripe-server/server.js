require('dotenv').config();
const express = require('express');
const cors = require('cors');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const app = express();
app.use(cors());
app.use(express.json());

app.post('/createPaymentIntent', async (req, res) => {
  try {
    const { amount, currency = 'usd', jobId, customerId } = req.body;

    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'Invalid amount' });
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      automatic_payment_methods: { enabled: true },
      metadata: { jobId, customerId },
    });

    res.json({ clientSecret: paymentIntent.client_secret });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

app.post('/confirmPayment', async (req, res) => {
  try {
    const { clientSecret, paymentMethodId } = req.body;
    if (!clientSecret || !paymentMethodId) {
      return res.status(400).json({ error: 'Missing clientSecret or paymentMethodId' });
    }

    const paymentIntentId = clientSecret.split('_secret_')[0];
    const paymentIntent = await stripe.paymentIntents.confirm(paymentIntentId, {
      payment_method: paymentMethodId,
    });

    res.json({
      success: paymentIntent.status === 'succeeded',
      status: paymentIntent.status,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

const PORT = 3000;
app.listen(PORT, () => console.log(`Stripe server running on http://localhost:${PORT}`));
