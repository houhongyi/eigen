/* tslint:disable */
/* eslint-disable */
// @ts-nocheck

import { ReaderFragment } from "relay-runtime";
import { FragmentRefs } from "relay-runtime";
export type ArtistAbout_artist = {
    readonly has_metadata: boolean | null;
    readonly is_display_auction_link: boolean | null;
    readonly slug: string;
    readonly related: {
        readonly artists: {
            readonly edges: ReadonlyArray<{
                readonly node: {
                    readonly " $fragmentRefs": FragmentRefs<"RelatedArtists_artists">;
                } | null;
            } | null> | null;
        } | null;
    } | null;
    readonly articles: {
        readonly edges: ReadonlyArray<{
            readonly node: {
                readonly " $fragmentRefs": FragmentRefs<"Articles_articles">;
            } | null;
        } | null> | null;
    } | null;
    readonly " $fragmentRefs": FragmentRefs<"Biography_artist" | "ArtistConsignButton_artist">;
    readonly " $refType": "ArtistAbout_artist";
};
export type ArtistAbout_artist$data = ArtistAbout_artist;
export type ArtistAbout_artist$key = {
    readonly " $data"?: ArtistAbout_artist$data;
    readonly " $fragmentRefs": FragmentRefs<"ArtistAbout_artist">;
};



const node: ReaderFragment = {
  "argumentDefinitions": [],
  "kind": "Fragment",
  "metadata": null,
  "name": "ArtistAbout_artist",
  "selections": [
    {
      "alias": "has_metadata",
      "args": null,
      "kind": "ScalarField",
      "name": "hasMetadata",
      "storageKey": null
    },
    {
      "alias": "is_display_auction_link",
      "args": null,
      "kind": "ScalarField",
      "name": "isDisplayAuctionLink",
      "storageKey": null
    },
    {
      "alias": null,
      "args": null,
      "kind": "ScalarField",
      "name": "slug",
      "storageKey": null
    },
    {
      "alias": null,
      "args": null,
      "concreteType": "ArtistRelatedData",
      "kind": "LinkedField",
      "name": "related",
      "plural": false,
      "selections": [
        {
          "alias": "artists",
          "args": [
            {
              "kind": "Literal",
              "name": "first",
              "value": 16
            }
          ],
          "concreteType": "ArtistConnection",
          "kind": "LinkedField",
          "name": "artistsConnection",
          "plural": false,
          "selections": [
            {
              "alias": null,
              "args": null,
              "concreteType": "ArtistEdge",
              "kind": "LinkedField",
              "name": "edges",
              "plural": true,
              "selections": [
                {
                  "alias": null,
                  "args": null,
                  "concreteType": "Artist",
                  "kind": "LinkedField",
                  "name": "node",
                  "plural": false,
                  "selections": [
                    {
                      "args": null,
                      "kind": "FragmentSpread",
                      "name": "RelatedArtists_artists"
                    }
                  ],
                  "storageKey": null
                }
              ],
              "storageKey": null
            }
          ],
          "storageKey": "artistsConnection(first:16)"
        }
      ],
      "storageKey": null
    },
    {
      "alias": "articles",
      "args": [
        {
          "kind": "Literal",
          "name": "first",
          "value": 10
        }
      ],
      "concreteType": "ArticleConnection",
      "kind": "LinkedField",
      "name": "articlesConnection",
      "plural": false,
      "selections": [
        {
          "alias": null,
          "args": null,
          "concreteType": "ArticleEdge",
          "kind": "LinkedField",
          "name": "edges",
          "plural": true,
          "selections": [
            {
              "alias": null,
              "args": null,
              "concreteType": "Article",
              "kind": "LinkedField",
              "name": "node",
              "plural": false,
              "selections": [
                {
                  "args": null,
                  "kind": "FragmentSpread",
                  "name": "Articles_articles"
                }
              ],
              "storageKey": null
            }
          ],
          "storageKey": null
        }
      ],
      "storageKey": "articlesConnection(first:10)"
    },
    {
      "args": null,
      "kind": "FragmentSpread",
      "name": "Biography_artist"
    },
    {
      "args": null,
      "kind": "FragmentSpread",
      "name": "ArtistConsignButton_artist"
    }
  ],
  "type": "Artist",
  "abstractKey": null
};
(node as any).hash = 'f83a9812ee25ef6aeb7eb17e2e269837';
export default node;
