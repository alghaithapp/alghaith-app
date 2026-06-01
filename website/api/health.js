module.exports = async function health(_, res) {
  res.status(200).json({ ok: true });
};
