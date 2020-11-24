import { ArtistAboutShows_artist } from "__generated__/ArtistAboutShows_artist.graphql"
import { extractNodes } from "lib/utils/extractNodes"
import { Button, Flex, Spacer, Text } from "palette"
import React from "react"
import { FlatList } from "react-native"
import { createFragmentContainer, createPaginationContainer, graphql } from "react-relay"
import { useScreenDimensions } from "../../../utils/useScreenDimensions"
import { ArtistShowFragmentContainer } from "../ArtistShows/ArtistShow"

interface Props {
  artist: ArtistAboutShows_artist
}

const ArtistAboutShows: React.FC<Props> = ({ artist }) => {
  console.log({ artist })
  const currentShows = extractNodes(artist.currentShows)
  const upcomingShows = extractNodes(artist.upcomingShows)
  const currentAndUpcomingShows = [...currentShows, ...upcomingShows]

  const pastShows = extractNodes(artist.pastShows)
  const screenWidth = useScreenDimensions().width

  // We show the current and upcoming shows. If no current/upcoming, we show the 3 past shows
  // See https://artsyproduct.atlassian.net/browse/CX-743 for business rules
  const shownShows = currentAndUpcomingShows.length > 0 ? currentAndUpcomingShows : pastShows

  const userHasShows = currentAndUpcomingShows.length + pastShows.length

  if (userHasShows) {
    return (
      <Flex position="absolute">
        <Text variant="subtitle" mb={1}>
          Shows featuring Nicolas Party
        </Text>
        <FlatList
          data={shownShows}
          renderItem={({ item }) => (
            <ArtistShowFragmentContainer
              show={item}
              styles={{
                container: {
                  width: screenWidth - 80,
                },
                image: {
                  width: screenWidth - 80,
                  height: 220,
                  marginRight: 15,
                  marginBottom: 10,
                },
              }}
            />
          )}
          ItemSeparatorComponent={() => <Spacer width={10} />}
          keyExtractor={(show) => show.id}
          showsHorizontalScrollIndicator={false}
          horizontal
          contentContainerStyle={{ paddingBottom: 15 }}
        />
        {!!pastShows.length && (
          <Button
            variant={"secondaryGray"}
            onPress={() => {
              console.log("do nothing")
            }}
            size="medium"
            block
          >
            See all past shows
          </Button>
        )}
      </Flex>
    )
  }

  // If the user has no past/current/upcoming shows
  return null
}

export const ArtistAboutShowsFragmentContainer = createFragmentContainer(ArtistAboutShows, {
  artist: graphql`
    fragment ArtistAboutShows_artist on Artist {
      currentShows: showsConnection(status: "running", first: 10) {
        edges {
          node {
            id
            ...ArtistShow_show
          }
        }
      }
      upcomingShows: showsConnection(status: "upcoming", first: 10) {
        edges {
          node {
            id
            ...ArtistShow_show
          }
        }
      }
      pastShows: showsConnection(status: "closed", first: 3) {
        edges {
          node {
            id
            ...ArtistShow_show
          }
        }
      }
    }
  `,
})

export const ArtistAboutShowsPaginationContainer = createPaginationContainer(ArtistAboutShows, {}, {})
