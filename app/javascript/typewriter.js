import Typewriter from "typewriter-effect/dist/core";

// https://github.com/tameemsafi/typewriterjs

const quote = document.querySelector("#quote");

new Typewriter(quote, {
  strings: [
    "Travel planning is so much easier with TabiNow!",
    "I always use TabiNow when I need to plan a trip.",
    "Simple, quick, and stress-free!",
  ],
  autoStart: true,
  pauseFor: 1600,
  deleteSpeed: 100,
  loop: true,
});
