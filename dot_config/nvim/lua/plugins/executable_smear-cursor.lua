return {
  {
    "sphamba/smear-cursor.nvim",
    event = "VeryLazy",
    opts = {
      -- Keep the cursor motion smooth with a small trail so the cursor is easy to track.
      stiffness = 0.8,
      trailing_stiffness = 0.35,
      stiffness_insert_mode = 0.5,
      trailing_stiffness_insert_mode = 0.35,
      matrix_pixel_threshold = 0.5,
      smear_insert_mode = true,
      legacy_computing_symbols_support = true,
      trailing_exponent = 2,
      damping = 0.92,
      distance_stop_animating = 0.3,
      time_interval = 22,
    },
  },
}