Add:
- Property on materials that allow it to be force ignored by the AuctionPricing service.
- Add support for Wowhead links to the multi-link popup?
  - Bronze Bar, for example, has multi-link support for Copper and Tin Ore farming pages on WoW-Professions;
    I want the same for Wowhead, just to the item pages for Copper and Tin Ore instead
- Add support for gathering profession leveling guides
  - There should be skill level headers and maps beneath them
    - The maps should have faction flags or be neutral
  - The maps should be clickable and import into Routes addon
    - Add some sort of fancy border to the maps so it's not just an image file sitting on the frame (yuck!)
    - Detect if the Routes Import/Export addon is loaded
    - Prompt the player if they want to import a route for the zone
    - Check to see if I can automatically optimize the route and change the color of the line
      - Blue: Herbalism
      - Yellow: Mining

Fix These:
- Material count should decrement with each skill-up.
- Materials should be greyed out and "disabled" when the player has met the required count.
  - Disabled materials should no longer have a tooltip but the WoW-Professions and Wowhead buttons should continue to work.
- When all steps that use a given material are completed, that material's N/N count should be hidden from the materials list.

Before Release:
Clean the code for any unnecessary shit.