---
date: '2026-11-14T22:00:00+01:00'
draft: false
title: 'Crossplane ou Terraform : un benchmark sur un cluster local (en cours)'
tags: ["kubernetes", "crossplane", "terraform", "iac", "benchmark"]
summary: "Je provisionne la même pile avec les deux outils et je les compare sur des critères fixés à l'avance. Projet en cours : la méthode et les premiers constats."
---

> Projet en cours. Cette page est mise à jour à chaque étape. Elle décrit la méthode et ce qui a été fait jusqu'ici. Les résultats du benchmark viendront ensuite.

## Objectif

Terraform applique un plan à un instant donné, puis s'arrête. Crossplane tourne en permanence dans un cluster Kubernetes et corrige en continu l'écart entre ce qui est déclaré et ce qui existe. Sur le papier, la différence est claire. Je voulais la voir de mes propres yeux, et savoir ce qu'elle change en pratique.

Le lab pose donc une question simple : si je provisionne la même pile avec les deux outils, sur le même cluster, lequel se comporte le mieux, et dans quelles situations ?

Je connaissais Terraform, que j'utilise pour [ce site](/projets/portfolio-iac/). Je ne connaissais ni Crossplane ni l'exploitation d'un cluster Kubernetes. Le lab sert aussi à combler ce manque.

## La pile

Quatre ressources qui dépendent les unes des autres, en deux variantes, dev et prod :

- un réseau : un namespace et une NetworkPolicy ;
- un serveur PostgreSQL avec un volume persistant ;
- un service web ;
- une base applicative et son compte, créés par l'API de PostgreSQL.

La dernière compte plus qu'il n'y paraît. Ce n'est pas un objet Kubernetes : l'outil doit parler à un système extérieur pour la créer. C'est le cas le plus proche d'un service managé qu'on puisse reproduire en local.

Tout tourne sur un cluster kind à un node, sans compte cloud.

## La méthode

Avant d'installer Crossplane, j'ai écrit la pile à la main, en YAML. Je voulais savoir ce que les outils auraient à générer, et pouvoir déboguer ce qu'ils produiraient.

J'ai ensuite figé la grille du benchmark, avant toute mesure. Choisir les critères après avoir vu les résultats revient à arranger la conclusion. La grille contient 16 critères, chacun avec un scénario et une façon de mesurer. Six sont prioritaires :

| Critère | Scénario |
|---|---|
| Dérive | Je modifie une ressource à la main. Que se passe-t-il, et en combien de temps ? |
| Abstraction | J'ajoute une variante `staging`. Combien de fichiers et de lignes ? |
| Dégradation | Une ressource sur quatre échoue. Dans quel état sont les trois autres ? |
| Ordonnancement | Les ressources sont-elles créées dans le bon ordre, et à quel prix ? |
| Évolution d'un modèle | Je change le modèle. Comment le changement atteint-il ce qui est déjà déployé ? |
| Coexistence | Terraform a créé une ressource. Crossplane peut-il la reprendre sans la recréer ? |

Chaque critère est marqué comme mesurable, comme jugement ou comme raisonnement. Le passage à l'échelle, par exemple, ne se mesure pas sur un portable : il sera présenté comme une extrapolation, pas comme un résultat.

La grille liste aussi ses biais. Je connais mieux Terraform que Crossplane, et je risque de juger le second plus difficile par manque de pratique.

## Où j'en suis

- La pile écrite à la main fonctionne, et chaque mécanisme a été vérifié par un test : persistance des données, isolation réseau, droits.
- Crossplane 2.4 est installé, avec un premier provider.
- Crossplane a créé une première base dans PostgreSQL.

Il reste l'essentiel : l'abstraction avec Crossplane, les mesures, puis la même chose avec Terraform.

## Premiers constats

Ce ne sont pas encore des résultats, seulement ce que la mise en place a montré.

**Crossplane a un coût au repos.** Le cluster consomme 1,20 Go avec la pile seule, 1,37 Go avec Crossplane, 1,50 Go avec un provider. Terraform, lui, ne consomme rien entre deux exécutions.

**Un provider, ce sont beaucoup de types.** Le cœur de Crossplane ajoute 21 types d'objets au cluster. Un petit provider SQL en ajoute 39. Un provider de grand cloud en apporte plusieurs centaines.

**La couverture des providers est inégale.** J'avais prévu un bucket MinIO. Avant de l'installer, j'ai vérifié l'état des projets : le dépôt MinIO était archivé, et le provider Crossplane correspondant n'avait pas eu de release depuis plus d'un an. J'ai changé la pile, et j'ai tracé le changement dans la grille avec sa raison.

**Une panne mal signalée.** Ma propre NetworkPolicy bloquait le provider, qui tourne dans un autre namespace que la base. La politique faisait son travail. Mais le statut de la ressource affichait encore une ancienne erreur, sans rapport, et les journaux du provider étaient vides. J'ai trouvé la cause avec un test de connexion manuel. Je m'attendais à ce que la réconciliation continue rende les pannes plus visibles. Sur ce cas, non.

**Un `apply` accepté ne prouve rien.** Kubernetes enregistre ce qu'on lui demande et rend la main. Une règle réseau qui ne s'applique pas ou un service qui ne trouve aucun pod ne déclenchent aucune erreur. Il faut tester.

## La suite

1. Décrire la pile comme une API avec Crossplane, puis jouer les scénarios.
2. Refaire la pile avec un module Terraform, et jouer les mêmes scénarios.
3. Publier le tableau comparatif et la conclusion.
4. Ajouter une pipeline GitHub Actions qui valide les deux implémentations.

## Code source

Le dépôt contient les manifestes, la grille complète et les notes de mesure : [GitHub](https://github.com/SleideWilson/lab-crossplane-terraform).
