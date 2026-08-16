enum CampaignTraversalAbility { wallJump, airDash, terrainPulse }

extension CampaignTraversalAbilityPresentation on CampaignTraversalAbility {
  String get localizationKey => 'ability.$name.name';

  String get descriptionLocalizationKey => 'ability.$name.description';
}
