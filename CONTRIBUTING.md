# Contributing

Contributions that improve gait-event detection, coordinate-transform robustness,
or documentation are welcome.

1. Fork the repository and create a feature branch.
2. Follow the existing code style: one public function per file, H1 help line,
   section comments, SI units, and 1-based indexing (MATLAB convention).
3. Verify your change end-to-end by running the example script, which must still
   complete without warnings and regenerate every table and figure in `outputs/`:
   ```matlab
   run('src/example_gait_analysis.m')
   ```
4. Open a pull request describing the change and the rationale.

Please report bugs and methodological questions as GitHub Issues.
