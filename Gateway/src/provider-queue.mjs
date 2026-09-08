export function createSerialProviderQueue() {
  let tail = Promise.resolve();

  return {
    async run(operation) {
      const previous = tail;
      let release;
      tail = new Promise((resolve) => {
        release = resolve;
      });

      await previous;
      try {
        return await operation();
      } finally {
        release();
      }
    }
  };
}
